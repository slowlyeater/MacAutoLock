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
    @Published var lastBluetoothRSSI: Int?
    @Published var autoLockStatus = "Waiting for trusted iPhone."

    private let lockController = MacLockController()
    private let engine = AutoLockEngine()
    private let bluetoothScanner = MacBluetoothPresenceScanner()
    private let trustedStore = TrustedDeviceStore()
    private var timer: Timer?
    private let deviceId = DeviceIdentity.loadOrCreate()
    private var trustedDeviceIds: Set<UUID> = []
    private var handledLockRequests: Set<UUID> = []
    private var rssiSmoothers: [UUID: RSSISmoother] = [:]
    private var didAutoLockForCurrentAway = false

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
        bluetoothScanner.start()
        appendLog("Bluetooth scanner started.")

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
        appendLog(reason)
        lockState = .locked
        lockController.lockScreen()
    }

    func regeneratePairingCode() {
        pairingCode = PairingCodeValidator.generate()
        appendLog("Pairing code refreshed.")
    }

    func setMinimumNearbyRSSI(_ value: Int) {
        rule.minimumNearbyRSSI = value
        updateAutoLockState()
    }

    func trust(_ peer: PeerState) {
        trustedDeviceIds.insert(peer.id)
        trustedStore.save(trustedDeviceIds)
        upsertPeer(
            PeerState(
                id: peer.id,
                deviceName: peer.deviceName,
                role: peer.role,
                lastHeartbeat: peer.lastHeartbeat ?? Date(),
                lastNearbyHeartbeat: peer.isConnected ? Date() : peer.lastNearbyHeartbeat,
                lastRSSI: peer.lastRSSI,
                isConnected: peer.isConnected,
                isTrusted: true
            )
        )
        appendLog("Manually trusted \(peer.deviceName).")
    }

    private func tick() {
        updateAutoLockState()
    }

    private func updateAutoLockState(now: Date = Date()) {
        guard rule.isAutoLockEnabled else {
            autoLockStatus = "Auto lock is disabled."
            return
        }

        let trusted = peers.filter(\.isTrusted)
        guard trusted.isEmpty == false else {
            autoLockStatus = "Pair or trust an iPhone first."
            return
        }

        let activeTrusted = trusted.filter { peer in
            guard let lastHeartbeat = peer.lastHeartbeat else { return false }
            return now.timeIntervalSince(lastHeartbeat) <= rule.offlineGraceSeconds
        }

        if let nearby = activeTrusted.first(where: { ($0.lastRSSI ?? -127) >= rule.minimumNearbyRSSI }) {
            didAutoLockForCurrentAway = false
            autoLockStatus = "\(nearby.deviceName) nearby, RSSI \(nearby.lastRSSI ?? 0) >= \(rule.minimumNearbyRSSI)."
            return
        }

        if let weak = activeTrusted.first {
            autoLockStatus = "\(weak.deviceName) crossed threshold, RSSI \(weak.lastRSSI ?? 0) < \(rule.minimumNearbyRSSI)."
            if didAutoLockForCurrentAway == false {
                didAutoLockForCurrentAway = true
                lockNow(reason: "Trusted iPhone crossed RSSI threshold: \(weak.lastRSSI ?? 0) < \(rule.minimumNearbyRSSI).")
            }
            return
        }

        autoLockStatus = "Trusted iPhone has not reported for \(Int(rule.offlineGraceSeconds))s."
        if didAutoLockForCurrentAway == false {
            didAutoLockForCurrentAway = true
            lockNow(reason: "Trusted iPhone stopped reporting for \(Int(rule.offlineGraceSeconds))s.")
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
        logLines.insert("[\(stamp)] \(line)", at: 0)
        logLines = Array(logLines.prefix(8))
    }
}
