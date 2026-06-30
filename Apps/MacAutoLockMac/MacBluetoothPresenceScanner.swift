import CoreBluetooth
import Foundation
#if SWIFT_PACKAGE
import MacAutoLockShared
#endif

final class MacBluetoothPresenceScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onPresence: ((BluetoothPresenceEvent) -> Void)?
    var onStatus: ((String) -> Void)?

    private lazy var central = CBCentralManager(delegate: self, queue: nil)
    private let serviceUUID = CBUUID(string: BluetoothPresence.serviceUUID)
    private let identityUUID = CBUUID(string: BluetoothPresence.identityCharacteristicUUID)
    private let decoder = JSONDecoder()
    private var discoveredRSSI: [UUID: Int] = [:]
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var lastReadAttempt: [UUID: Date] = [:]
    private let minimumReadInterval: TimeInterval = 1.5

    func start() {
        _ = central
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            onStatus?("Bluetooth scanning")
            central.scanForPeripherals(withServices: [serviceUUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ])
        case .poweredOff:
            onStatus?("Bluetooth is off")
        case .unauthorized:
            onStatus?("Bluetooth permission denied")
        case .unsupported:
            onStatus?("Bluetooth unsupported")
        default:
            onStatus?("Bluetooth unavailable")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let now = Date()
        discoveredRSSI[peripheral.identifier] = RSSI.intValue
        guard shouldRead(peripheral: peripheral, now: now) else { return }

        lastReadAttempt[peripheral.identifier] = now
        peripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        peripherals[peripheral.identifier] = nil
        onStatus?("Bluetooth connect failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripherals[peripheral.identifier] = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.discoverCharacteristics([identityUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == identityUUID }) else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        defer {
            central.cancelPeripheralConnection(peripheral)
            peripherals[peripheral.identifier] = nil
        }
        guard let data = characteristic.value else { return }

        do {
            let payload = try decoder.decode(BluetoothIdentityPayload.self, from: data)
            let event = BluetoothPresenceEvent(
                deviceId: payload.deviceId,
                deviceName: payload.deviceName,
                role: payload.role,
                rssi: discoveredRSSI[peripheral.identifier] ?? 0,
                pairingCode: payload.pairingCode,
                lockRequestId: payload.lockRequestId
            )
            onPresence?(event)
            onStatus?("Bluetooth device nearby")
        } catch {
            onStatus?("Bluetooth identity unreadable")
        }
    }

    private func shouldRead(peripheral: CBPeripheral, now: Date) -> Bool {
        switch peripheral.state {
        case .connected, .connecting, .disconnecting:
            return false
        case .disconnected:
            guard let lastAttempt = lastReadAttempt[peripheral.identifier] else { return true }
            return now.timeIntervalSince(lastAttempt) >= minimumReadInterval
        @unknown default:
            return false
        }
    }
}
