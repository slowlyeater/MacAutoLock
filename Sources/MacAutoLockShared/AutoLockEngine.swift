import Foundation

public struct AutoLockDecision: Equatable, Sendable {
    public var shouldLock: Bool
    public var reason: String

    public init(shouldLock: Bool, reason: String) {
        self.shouldLock = shouldLock
        self.reason = reason
    }
}

public struct AutoLockEngine: Sendable {
    public init() {}

    public func evaluate(rule: AutoLockRule, trustedPeers: [PeerState], now: Date = Date()) -> AutoLockDecision {
        guard rule.isAutoLockEnabled else {
            return AutoLockDecision(shouldLock: false, reason: "Auto lock is disabled.")
        }

        let trusted = trustedPeers.filter(\.isTrusted)
        guard !trusted.isEmpty else {
            return AutoLockDecision(shouldLock: false, reason: "No trusted devices are paired yet.")
        }

        let activeTrusted = trusted.filter { peer in
            guard let lastHeartbeat = peer.lastHeartbeat else {
                return false
            }
            return now.timeIntervalSince(lastHeartbeat) <= rule.offlineGraceSeconds
        }

        if activeTrusted.contains(where: { ($0.lastRSSI ?? -127) >= rule.minimumNearbyRSSI }) {
            return AutoLockDecision(shouldLock: false, reason: "A trusted device is nearby.")
        }

        if let weakPeer = activeTrusted.first {
            return AutoLockDecision(
                shouldLock: true,
                reason: "\(weakPeer.deviceName) crossed the RSSI threshold."
            )
        }

        return AutoLockDecision(shouldLock: true, reason: "Trusted devices stopped reporting.")
    }
}
