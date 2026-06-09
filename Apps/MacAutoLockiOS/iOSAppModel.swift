import Foundation
#if SWIFT_PACKAGE
import MacAutoLockShared
#endif
import SwiftUI
import UIKit

@MainActor
final class iOSAppModel: ObservableObject {
    @Published var pairingCode = ""
    @Published var broadcastName = UIDevice.current.name
    @Published var bluetoothStatus = "Bluetooth starting"
    @Published var lastLockRequestId: UUID?
    @Published private(set) var isPairingCodeConfirmed = false

    let deviceId = DeviceIdentity.loadOrCreate()

    private lazy var bluetoothAdvertiser = iOSBluetoothAdvertiser(payload: bluetoothPayload())
    private lazy var watchRelay = iOSWatchRelay()

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
        refreshBluetoothPayload()
    }

    func confirmPairing() {
        guard PairingCodeValidator.normalized(pairingCode) != nil else { return }
        isPairingCodeConfirmed = true
        refreshBluetoothPayload()
    }

    func refreshBluetoothPayload() {
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
            deviceName: broadcastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UIDevice.current.name : broadcastName,
            role: .iphone,
            pairingCode: isPairingCodeConfirmed ? normalizedPairingCode : nil,
            lockRequestId: lastLockRequestId
        )
    }
}
