import Foundation

enum DeviceIdentity {
    private static let key = "MacAutoLockDeviceId"

    static func loadOrCreate() -> UUID {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: key), let uuid = UUID(uuidString: value) {
            return uuid
        }

        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: key)
        return uuid
    }
}
