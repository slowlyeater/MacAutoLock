import Foundation

struct TrustedDeviceStore {
    private let key = "MacAutoLockTrustedDeviceIds"

    func load() -> Set<UUID> {
        let values = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(values.compactMap(UUID.init(uuidString:)))
    }

    func save(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString).sorted(), forKey: key)
    }
}
