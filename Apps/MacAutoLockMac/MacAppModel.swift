import Foundation
#if SWIFT_PACKAGE
import MacAutoLockShared
#endif
import SwiftUI

@MainActor
final class MacAppModel: ObservableObject {
    @Published var lockState: LockState = .unknown
    @Published var peers: [PeerState] = []
    @Published var rule = AutoLockRule()
    @Published var logLines: [String] = []
    @Published var pairingCode = PairingCodeValidator.generate()
    @Published var bluetoothStatus = "Bluetooth starting"
    @Published var bluetoothState = "unknown"
    @Published var isScanning = false
    @Published var lastScanAt: Date?
    @Published var lastBluetoothRSSI: Int?
    @Published var autoLockStatus = "Waiting for trusted iPhone."
    @Published var isDebugMode = false
    @Published var isDryRun = true
    @Published var debugDevices: [MacDebugDeviceState] = []

    private let lockController = MacLockController()
    private let engine = AutoLockEngine()
    private let bluetoothScanner = MacBluetoothPresenceScanner()
    private let trustedStore = TrustedDeviceStore()
    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private let deviceId = DeviceIdentity.loadOrCreate()
    private var trustedDeviceIds: Set<UUID> = []
    private var handledLockRequests: Set<UUID> = []
    private var rssiSmoothers: [UUID: RSSISmoother] = [:]
    private var didAutoLockForCurrentAway = false
    private let thresholdKey = "macAutoLock.rssiThreshold"
    private let dryRunKey = "macAutoLock.dryRun"
    private let debugModeKey = "macAutoLock.debugMode"

    init() {
        let savedThreshold = defaults.object(forKey: thresholdKey) as? Int
        rule.minimumNearbyRSSI = savedThreshold ?? rule.minimumNearbyRSSI
        isDryRun = defaults.object(forKey: dryRunKey) == nil ? true : defaults.bool(forKey: dryRunKey)
        isDebugMode = defaults.object(forKey: debugModeKey) == nil ? false : defaults.bool(forKey: debugModeKey)
    }

    func start() {
        guard timer == nil else { return }
        trustedDeviceIds = trustedStore.load()

        bluetoothScanner.onPresence = { [weak self] event in
            Task { @MainActor in
                self?.handleBluetoothPresence(event)
            }
        }
        bluetoothScanner.onStatus = { [weak self] status in
            Task { @MainActor in
                self?.bluetoothStatus = status
            }
        }
        bluetoothScanner.onBluetoothState = { [weak self] state in
            Task { @MainActor in
                self?.bluetoothState = state
            }
        }
        bluetoothScanner.onScanningChanged = { [weak self] isScanning in
            Task { @MainActor in
                self?.isScanning = isScanning
                self?.appendLog(isScanning ? "scan started" : "scan stopped")
            }
        }
        bluetoothScanner.onScanActivity = { [weak self] date in
            Task { @MainActor in
                self?.lastScanAt = date
            }
        }
        bluetoothScanner.start()
        appendLog("Bluetooth scanner started")

        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func toggleAutoLock() {
        rule.isAutoLockEnabled.toggle()
        appendLog("Auto lock \(rule.isAutoLockEnabled ? "enabled" : "disabled").")
    }

    func lockNow(reason: String = "Manual lock requested.") {
        if isDryRun {
            appendLog("would lock: \(reason)")
            return
        }

        lockState = .locked
        appendLog(reason)
        if lockController.lockScreen() {
            appendLog("lock executed")
        } else {
            appendLog("lock failed: no lock strategy succeeded")
        }
    }

    func regeneratePairingCode() {
        pairingCode = PairingCodeValidator.generate()
        appendLog("Pairing code refreshed.")
    }

    func setMinimumNearbyRSSI(_ value: Int) {
        rule.minimumNearbyRSSI = value
        defaults.set(value, forKey: thresholdKey)
        appendLog("threshold set to \(value)")
        updateAutoLockState()
    }

    func setDebugMode(_ isEnabled: Bool) {
        isDebugMode = isEnabled
        defaults.set(isEnabled, forKey: debugModeKey)
        appendLog("debug mode \(isEnabled ? "enabled" : "disabled")")
    }

    func setDryRun(_ isEnabled: Bool) {
        isDryRun = isEnabled
        defaults.set(isEnabled, forKey: dryRunKey)
        appendLog("dry run \(isEnabled ? "enabled" : "disabled")")
    }

    func untrust(_ peer: PeerState) {
        trustedDeviceIds.remove(peer.id)
        trustedStore.save(trustedDeviceIds)
        upsertPeer(
            PeerState(
                id: peer.id,
                deviceName: peer.deviceName,
                role: peer.role,
                lastHeartbeat: peer.lastHeartbeat ?? Date(),
                lastNearbyHeartbeat: peer.lastNearbyHeartbeat,
                lastRSSI: peer.lastRSSI,
                isConnected: peer.isConnected,
                isTrusted: false
            )
        )
        if let index = debugDevices.firstIndex(where: { $0.id == peer.id }) {
            debugDevices[index].isTrusted = false
            debugDevices[index].status = "untrusted"
        }
        didAutoLockForCurrentAway = false
        appendLog("Untrusted \(peer.deviceName).")
        updateAutoLockState()
    }

    private func tick() {
        updateAutoLockState()
    }

    private func updateAutoLockState(now: Date = Date()) {
        let decision = engine.evaluate(rule: rule, trustedPeers: peers, now: now)
        autoLockStatus = decision.reason
        refreshDebugDeviceStatuses(now: now, decision: decision)

        if decision.kind == .nearby {
            didAutoLockForCurrentAway = false
        }

        guard decision.shouldLock, didAutoLockForCurrentAway == false else { return }
        didAutoLockForCurrentAway = true

        switch decision.kind {
        case .weakRSSI:
            let weakPeer = peers.first { peer in
                peer.isTrusted
                    && (peer.lastHeartbeat.map { now.timeIntervalSince($0) <= rule.offlineGraceSeconds } ?? false)
                    && (peer.lastRSSI ?? -127) < rule.minimumNearbyRSSI
            }
            let rssi = weakPeer?.lastRSSI.map(String.init) ?? "unknown"
            lockNow(reason: "weak RSSI for trusted iPhone: \(rssi) < \(rule.minimumNearbyRSSI)")
        case .missing:
            lockNow(reason: "trusted iPhone missing for \(Int(rule.offlineGraceSeconds))s")
        default:
            lockNow(reason: decision.reason)
        }
    }

    private func handleBluetoothPresence(_ event: BluetoothPresenceEvent) {
        var smoother = rssiSmoothers[event.deviceId] ?? RSSISmoother()
        let smoothedRSSI = smoother.addSample(event.rssi)
        rssiSmoothers[event.deviceId] = smoother

        lastBluetoothRSSI = smoothedRSSI
        let isNearby = smoothedRSSI >= rule.minimumNearbyRSSI
        let previousNearbyHeartbeat = peers.first(where: { $0.id == event.deviceId })?.lastNearbyHeartbeat
        let nearbyHeartbeat = isNearby ? event.timestamp : previousNearbyHeartbeat

        if trustedDeviceIds.contains(event.deviceId) == false {
            guard event.pairingCode == PairingCodeValidator.normalized(pairingCode) else {
                bluetoothStatus = "Nearby unpaired \(event.role.rawValue)"
                upsertPeer(
                    PeerState(
                        id: event.deviceId,
                        deviceName: event.deviceName,
                        role: event.role,
                        lastHeartbeat: event.timestamp,
                        lastNearbyHeartbeat: nearbyHeartbeat,
                        lastRSSI: smoothedRSSI,
                        isConnected: isNearby,
                        isTrusted: false
                    )
                )
                upsertDebugDevice(
                    event: event,
                    smoothedRSSI: smoothedRSSI,
                    isTrusted: false,
                    status: debugStatus(for: smoothedRSSI, isTrusted: false, now: event.timestamp, lastSeen: event.timestamp)
                )
                appendLog("\(event.deviceName) \(shortId(event.deviceId)) RSSI \(event.rssi) smooth \(smoothedRSSI) trusted false")
                return
            }

            trustedDeviceIds.insert(event.deviceId)
            trustedStore.save(trustedDeviceIds)
            regeneratePairingCode()
            appendLog("Bluetooth pairing accepted for \(event.deviceName).")
        }

        let peer = PeerState(
            id: event.deviceId,
            deviceName: event.deviceName,
            role: event.role,
            lastHeartbeat: event.timestamp,
            lastNearbyHeartbeat: nearbyHeartbeat,
            lastRSSI: smoothedRSSI,
            isConnected: isNearby,
            isTrusted: true
        )
        upsertPeer(peer)
        upsertDebugDevice(
            event: event,
            smoothedRSSI: smoothedRSSI,
            isTrusted: true,
            status: debugStatus(for: smoothedRSSI, isTrusted: true, now: event.timestamp, lastSeen: event.timestamp)
        )
        appendLog("\(event.deviceName) \(shortId(event.deviceId)) RSSI \(event.rssi) smooth \(smoothedRSSI) trusted true")
        bluetoothStatus = isNearby ? "Bluetooth nearby, RSSI \(smoothedRSSI)" : "Bluetooth weak, RSSI \(smoothedRSSI)"
        updateAutoLockState(now: event.timestamp)

        if let lockRequestId = event.lockRequestId,
           handledLockRequests.contains(lockRequestId) == false {
            handledLockRequests.insert(lockRequestId)
            lockNow(reason: "Bluetooth lock request from \(event.deviceName).")
        }
    }

    private func upsertPeer(_ peer: PeerState) {
        if let index = peers.firstIndex(where: { $0.id == peer.id }) {
            peers[index] = peer
        } else {
            peers.append(peer)
            appendLog("\(peer.isTrusted ? "Trusted" : "Unpaired") \(peer.role.rawValue): \(peer.deviceName).")
        }
    }

    private func appendLog(_ line: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logLines.insert("\(stamp) \(line)", at: 0)
        logLines = Array(logLines.prefix(30))
    }

    private func upsertDebugDevice(
        event: BluetoothPresenceEvent,
        smoothedRSSI: Int,
        isTrusted: Bool,
        status: String
    ) {
        let device = MacDebugDeviceState(
            id: event.deviceId,
            deviceName: event.deviceName,
            rawRSSI: event.rssi,
            smoothedRSSI: smoothedRSSI,
            threshold: rule.minimumNearbyRSSI,
            lastSeen: event.timestamp,
            isTrusted: isTrusted,
            status: status
        )

        if let index = debugDevices.firstIndex(where: { $0.id == event.deviceId }) {
            debugDevices[index] = device
        } else {
            debugDevices.append(device)
        }
        debugDevices.sort { $0.lastSeen > $1.lastSeen }
    }

    private func refreshDebugDeviceStatuses(now: Date, decision: AutoLockDecision) {
        debugDevices = debugDevices.map { device in
            var next = device
            next.threshold = rule.minimumNearbyRSSI
            next.status = deviceStatus(device: device, now: now, decision: decision)
            return next
        }
    }

    private func deviceStatus(device: MacDebugDeviceState, now: Date, decision: AutoLockDecision) -> String {
        guard device.isTrusted else { return "untrusted" }
        guard now.timeIntervalSince(device.lastSeen) <= rule.offlineGraceSeconds else { return "missing" }
        if device.smoothedRSSI >= rule.minimumNearbyRSSI { return "near" }
        if decision.shouldLock { return isDryRun ? "wouldLock" : "weak" }
        return "weak"
    }

    private func debugStatus(for smoothedRSSI: Int, isTrusted: Bool, now: Date, lastSeen: Date) -> String {
        guard isTrusted else { return "untrusted" }
        guard now.timeIntervalSince(lastSeen) <= rule.offlineGraceSeconds else { return "missing" }
        return smoothedRSSI >= rule.minimumNearbyRSSI ? "near" : "weak"
    }

    private func shortId(_ id: UUID) -> String {
        String(id.uuidString.prefix(6))
    }
}

struct MacDebugDeviceState: Identifiable, Equatable {
    var id: UUID
    var deviceName: String
    var rawRSSI: Int
    var smoothedRSSI: Int
    var threshold: Int
    var lastSeen: Date
    var isTrusted: Bool
    var status: String

    var shortDeviceId: String {
        String(id.uuidString.prefix(6))
    }
}
