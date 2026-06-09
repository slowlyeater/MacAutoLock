import Foundation

public enum BluetoothPresence {
    public static let serviceUUID = "B6F4AB9A-FA8B-4D1F-A578-4DBF4660882B"
    public static let identityCharacteristicUUID = "2E44E0C5-7B7C-46D1-9F54-3E5B187D12C7"
    public static let localName = "MacAutoLock"
}

public struct BluetoothIdentityPayload: Codable, Equatable, Sendable {
    public var deviceId: UUID
    public var deviceName: String
    public var role: DeviceRole
    public var pairingCode: String?
    public var lockRequestId: UUID?

    public init(
        deviceId: UUID,
        deviceName: String,
        role: DeviceRole,
        pairingCode: String? = nil,
        lockRequestId: UUID? = nil
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.role = role
        self.pairingCode = pairingCode
        self.lockRequestId = lockRequestId
    }
}

public struct BluetoothPresenceEvent: Equatable, Sendable {
    public var deviceId: UUID
    public var deviceName: String
    public var role: DeviceRole
    public var rssi: Int
    public var pairingCode: String?
    public var lockRequestId: UUID?
    public var timestamp: Date

    public init(
        deviceId: UUID,
        deviceName: String,
        role: DeviceRole,
        rssi: Int,
        pairingCode: String? = nil,
        lockRequestId: UUID? = nil,
        timestamp: Date = Date()
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.role = role
        self.rssi = rssi
        self.pairingCode = pairingCode
        self.lockRequestId = lockRequestId
        self.timestamp = timestamp
    }
}

public enum PairingCodeValidator {
    public static let requiredLength = 4

    public static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == requiredLength else { return nil }
        guard trimmed.allSatisfy(\.isNumber) else { return nil }
        return trimmed
    }

    public static func digitsOnlyPrefix(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(requiredLength))
    }

    public static func generate() -> String {
        String(format: "%04d", Int.random(in: 0...9_999))
    }
}
