import Foundation
#if SWIFT_PACKAGE
import MacAutoLockShared
#endif
import SwiftUI
import UIKit

@MainActor
final class iOSAppModel: ObservableObject {
    @Published var pairingCode: String
    @Published var broadcastName: String
    @Published var bluetoothStatus = "Bluetooth starting"
    @Published var lastLockRequestId: UUID?
    @Published private(set) var isPairingCodeConfirmed: Bool

    let deviceId = DeviceIdentity.loadOrCreate()

    private lazy var bluetoothAdvertiser = iOSBluetoothAdvertiser(payload: bluetoothPayload())
    private lazy var watchRelay = iOSWatchRelay()
    private let pairingStore = iOSPairingStore()
    private var hasStarted = false

    init() {
        let savedState = iOSPairingStore().load(defaultBroadcastName: UIDevice.current.name)
        pairingCode = savedState.pairingCode
        broadcastName = savedState.broadcastName
        isPairingCodeConfirmed = savedState.isConfirmed
    }

    var pairingCodeDigits: [String] {
        let digits = Array(pairingCode)
        return (0..<PairingCodeValidator.requiredLength).map { index in
            index < digits.count ? String(digits[index]) : ""
        }
    }

    var canConfirmPairing: Bool {
        PairingCodeValidator.normalized(pairingCode) != nil
    }

    var isEnabled: Bool {
        isPairingCodeConfirmed
    }

    func start() {
        guard hasStarted == false else { return }
        hasStarted = true

        bluetoothAdvertiser.onStatus = { [weak self] status in
            Task { @MainActor in
                self?.bluetoothStatus = status
            }
        }
        bluetoothAdvertiser.start()

        watchRelay.onLockRequest = { [weak self] in
            Task { @MainActor in
                self?.lockNow()
            }
        }
        watchRelay.start()
        refreshBluetoothPayload()
    }

    func lockNow() {
        lastLockRequestId = UUID()
        refreshBluetoothPayload()
    }

    func updatePairingCode(_ code: String) {
        pairingCode = PairingCodeValidator.digitsOnlyPrefix(code)
        isPairingCodeConfirmed = false
        savePairingState()
        refreshBluetoothPayload()
    }

    func confirmPairing() {
        guard PairingCodeValidator.normalized(pairingCode) != nil else { return }
        isPairingCodeConfirmed = true
        savePairingState()
        refreshBluetoothPayload()
    }

    func refreshBluetoothPayload() {
        savePairingState()
        bluetoothAdvertiser.updatePayload(bluetoothPayload())
        if let lastLockRequestId {
            watchRelay.sendStatus("BLE lock request \(lastLockRequestId.uuidString.prefix(8))")
        }
    }

    private func bluetoothPayload() -> BluetoothIdentityPayload {
        let trimmedPairingCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPairingCode = PairingCodeValidator.normalized(trimmedPairingCode)
        return BluetoothIdentityPayload(
            deviceId: deviceId,
            deviceName: effectiveBroadcastName,
            role: .iphone,
            pairingCode: isPairingCodeConfirmed ? normalizedPairingCode : nil,
            lockRequestId: lastLockRequestId
        )
    }

    private func savePairingState() {
        pairingStore.save(
            iOSPairingState(
                pairingCode: pairingCode,
                broadcastName: effectiveBroadcastName,
                isConfirmed: isPairingCodeConfirmed
            )
        )
    }

    private var effectiveBroadcastName: String {
        let trimmed = broadcastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UIDevice.current.name : trimmed
    }
}

private struct iOSPairingState {
    var pairingCode: String
    var broadcastName: String
    var isConfirmed: Bool
}

private struct iOSPairingStore {
    private let pairingCodeKey = "MacAutoLockPairingCode"
    private let broadcastNameKey = "MacAutoLockBroadcastName"
    private let confirmedKey = "MacAutoLockPairingConfirmed"

    func load(defaultBroadcastName: String) -> iOSPairingState {
        iOSPairingState(
            pairingCode: UserDefaults.standard.string(forKey: pairingCodeKey) ?? "",
            broadcastName: UserDefaults.standard.string(forKey: broadcastNameKey) ?? defaultBroadcastName,
            isConfirmed: UserDefaults.standard.bool(forKey: confirmedKey)
        )
    }

    func save(_ state: iOSPairingState) {
        UserDefaults.standard.set(state.pairingCode, forKey: pairingCodeKey)
        UserDefaults.standard.set(state.broadcastName, forKey: broadcastNameKey)
        UserDefaults.standard.set(state.isConfirmed, forKey: confirmedKey)
    }
}
