import Foundation

public enum AutoLockDecisionKind: String, Codable, Equatable, Sendable {
    case disabled
    case noTrustedDevice
    case nearby
    case weakRSSI
    case missing
}

public struct AutoLockDecision: Equatable, Sendable {
    public var shouldLock: Bool
    public var reason: String
    public var kind: AutoLockDecisionKind

    public init(shouldLock: Bool, reason: String, kind: AutoLockDecisionKind) {
        self.shouldLock = shouldLock
        self.reason = reason
        self.kind = kind
    }
}

public struct AutoLockEngine: Sendable {
    public init() {}

    public func evaluate(rule: AutoLockRule, trustedPeers: [PeerState], now: Date = Date()) -> AutoLockDecision {
        guard rule.isAutoLockEnabled else {
            return AutoLockDecision(shouldLock: false, reason: "Auto lock is disabled.", kind: .disabled)
        }

        let trusted = trustedPeers.filter(\.isTrusted)
        guard !trusted.isEmpty else {
            return AutoLockDecision(shouldLock: false, reason: "No trusted devices are paired yet.", kind: .noTrustedDevice)
        }

        let activeTrusted = trusted.filter { peer in
            guard let lastHeartbeat = peer.lastHeartbeat else {
                return false
            }
            return now.timeIntervalSince(lastHeartbeat) <= rule.offlineGraceSeconds
        }

        if activeTrusted.contains(where: { ($0.lastRSSI ?? -127) >= rule.minimumNearbyRSSI }) {
            return AutoLockDecision(shouldLock: false, reason: "A trusted device is nearby.", kind: .nearby)
        }

        if let weakPeer = activeTrusted.first {
            return AutoLockDecision(
                shouldLock: true,
                reason: "\(weakPeer.deviceName) crossed the RSSI threshold.",
                kind: .weakRSSI
            )
        }

        return AutoLockDecision(shouldLock: true, reason: "Trusted devices stopped reporting.", kind: .missing)
    }
}
