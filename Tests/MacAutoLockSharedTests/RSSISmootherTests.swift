import Testing
@testable import MacAutoLockShared

@Test
func rssiSmootherStartsWithFirstSample() {
    var smoother = RSSISmoother()
    #expect(smoother.addSample(-60) == -60)
    #expect(smoother.current == -60)
}

@Test
func rssiSmootherDampensSingleWeakSpike() {
    var smoother = RSSISmoother()
    _ = smoother.addSample(-60)
    _ = smoother.addSample(-62)
    let smoothed = smoother.addSample(-95)

    #expect(smoothed > -95)
    #expect(smoothed >= -78)
}

@Test
func rssiSmootherEventuallyFollowsSustainedWeakSignal() {
    var smoother = RSSISmoother()
    _ = smoother.addSample(-60)
    _ = smoother.addSample(-88)
    _ = smoother.addSample(-88)
    _ = smoother.addSample(-88)
    let smoothed = smoother.addSample(-88)

    #expect(smoothed <= -78)
}
