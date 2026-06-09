import Foundation
import Testing
@testable import MacAutoLockShared

@Test
func autoLockDoesNotFireWhenDisabled() {
    let engine = AutoLockEngine()
    let rule = AutoLockRule(isAutoLockEnabled: false)
    let peer = PeerState(deviceName: "iPhone", role: .iphone, lastHeartbeat: nil, isConnected: false, isTrusted: true)

    let decision = engine.evaluate(rule: rule, trustedPeers: [peer])

    #expect(decision.shouldLock == false)
}

@Test
func autoLockDoesNotFireForRecentTrustedHeartbeat() {
    let engine = AutoLockEngine()
    let now = Date(timeIntervalSince1970: 100)
    let rule = AutoLockRule(offlineGraceSeconds: 45)
    let peer = PeerState(
        deviceName: "iPhone",
        role: .iphone,
        lastHeartbeat: now.addingTimeInterval(-10),
        lastNearbyHeartbeat: now.addingTimeInterval(-10),
        lastRSSI: -50,
        isConnected: true,
        isTrusted: true
    )

    let decision = engine.evaluate(rule: rule, trustedPeers: [peer], now: now)

    #expect(decision.shouldLock == false)
}

@Test
func autoLockFiresAfterGraceWindow() {
    let engine = AutoLockEngine()
    let now = Date(timeIntervalSince1970: 100)
    let rule = AutoLockRule(offlineGraceSeconds: 45)
    let peer = PeerState(
        deviceName: "iPhone",
        role: .iphone,
        lastHeartbeat: now.addingTimeInterval(-60),
        lastNearbyHeartbeat: now.addingTimeInterval(-60),
        lastRSSI: -80,
        isConnected: false,
        isTrusted: true
    )

    let decision = engine.evaluate(rule: rule, trustedPeers: [peer], now: now)

    #expect(decision.shouldLock == true)
}

@Test
func autoLockFiresImmediatelyWhenSignalIsWeak() {
    let engine = AutoLockEngine()
    let now = Date(timeIntervalSince1970: 100)
    let rule = AutoLockRule(offlineGraceSeconds: 45, minimumNearbyRSSI: -75)
    let peer = PeerState(
        deviceName: "iPhone",
        role: .iphone,
        lastHeartbeat: now,
        lastNearbyHeartbeat: now,
        lastRSSI: -86,
        isConnected: false,
        isTrusted: true
    )

    let decision = engine.evaluate(rule: rule, trustedPeers: [peer], now: now)

    #expect(decision.shouldLock == true)
}

@Test
func autoLockIgnoresUntrustedPeers() {
    let engine = AutoLockEngine()
    let now = Date(timeIntervalSince1970: 100)
    let rule = AutoLockRule(offlineGraceSeconds: 45)
    let peer = PeerState(deviceName: "Other", role: .iphone, lastHeartbeat: now, isConnected: true, isTrusted: false)

    let decision = engine.evaluate(rule: rule, trustedPeers: [peer], now: now)

    #expect(decision.shouldLock == false)
}
