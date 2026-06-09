import Foundation

public enum DeviceRole: String, Codable, CaseIterable, Sendable {
    case mac
    case iphone
    case watch
}

public enum LockState: String, Codable, CaseIterable, Sendable {
    case unlocked
    case locked
    case unknown
}

public struct PeerState: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var deviceName: String
    public var role: DeviceRole
    public var lastHeartbeat: Date?
    public var lastNearbyHeartbeat: Date?
    public var lastRSSI: Int?
    public var isConnected: Bool
    public var isTrusted: Bool

    public init(
        id: UUID = UUID(),
        deviceName: String,
        role: DeviceRole,
        lastHeartbeat: Date? = nil,
        lastNearbyHeartbeat: Date? = nil,
        lastRSSI: Int? = nil,
        isConnected: Bool = false,
        isTrusted: Bool = false
    ) {
        self.id = id
        self.deviceName = deviceName
        self.role = role
        self.lastHeartbeat = lastHeartbeat
        self.lastNearbyHeartbeat = lastNearbyHeartbeat
        self.lastRSSI = lastRSSI
        self.isConnected = isConnected
        self.isTrusted = isTrusted
    }
}

public struct AutoLockRule: Codable, Equatable, Sendable {
    public var offlineGraceSeconds: TimeInterval
    public var minimumNearbyRSSI: Int
    public var isAutoLockEnabled: Bool
    public var isUnlockResearchEnabled: Bool

    public init(
        offlineGraceSeconds: TimeInterval = 45,
        minimumNearbyRSSI: Int = -75,
        isAutoLockEnabled: Bool = true,
        isUnlockResearchEnabled: Bool = true
    ) {
        self.offlineGraceSeconds = offlineGraceSeconds
        self.minimumNearbyRSSI = minimumNearbyRSSI
        self.isAutoLockEnabled = isAutoLockEnabled
        self.isUnlockResearchEnabled = isUnlockResearchEnabled
    }
}
