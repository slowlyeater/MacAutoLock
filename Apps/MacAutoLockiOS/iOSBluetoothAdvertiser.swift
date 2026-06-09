import CoreBluetooth
import Foundation
#if SWIFT_PACKAGE
import MacAutoLockShared
#endif

final class iOSBluetoothAdvertiser: NSObject, CBPeripheralManagerDelegate {
    var onStatus: ((String) -> Void)?

    private lazy var peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    private let serviceUUID = CBUUID(string: BluetoothPresence.serviceUUID)
    private let identityUUID = CBUUID(string: BluetoothPresence.identityCharacteristicUUID)
    private let encoder = JSONEncoder()
    private var payload: BluetoothIdentityPayload

    init(payload: BluetoothIdentityPayload) {
        self.payload = payload
        super.init()
    }

    func start() {
        _ = peripheralManager
    }

    func updatePayload(_ payload: BluetoothIdentityPayload) {
        self.payload = payload
        if peripheralManager.state == .poweredOn {
            restartAdvertising()
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            configureService()
            restartAdvertising()
            onStatus?("Bluetooth advertising")
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

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == identityUUID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }

        do {
            request.value = try encoder.encode(payload)
            peripheral.respond(to: request, withResult: .success)
        } catch {
            peripheral.respond(to: request, withResult: .unlikelyError)
        }
    }

    private func configureService() {
        peripheralManager.removeAllServices()
        let characteristic = CBMutableCharacteristic(
            type: identityUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager.add(service)
    }

    private func restartAdvertising() {
        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: BluetoothPresence.localName
        ])
    }
}
