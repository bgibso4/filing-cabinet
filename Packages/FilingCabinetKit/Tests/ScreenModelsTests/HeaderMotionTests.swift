import CoreGraphics
import Testing

@testable import ScreenModels

private let motion = HeaderMotion(largeHeight: 52)

@Test func growthIsOneFullyPulled() {
    #expect(motion.growth(offset: -20) == 1)
    #expect(motion.growth(offset: 0) == 1)
}

@Test func growthIsZeroCollapsed() {
    #expect(motion.growth(offset: 52) == 0)
    #expect(motion.growth(offset: 300) == 0)
}

@Test func growthIsLinearBetween() {
    #expect(motion.growth(offset: 26) == 0.5)
}

@Test func innerScreensRestSmall() {
    #expect(motion.restingOffset(.small) == 52)
}

@Test func homeRestsLarge() {
    #expect(motion.restingOffset(.large) == 0)
}

@Test func shortContentStillRestsSmall() {
    // Content one viewport tall plus the large title's height always leaves room to scroll it away.
    #expect(motion.minimumContentHeight(viewport: 700) == 752)
}
