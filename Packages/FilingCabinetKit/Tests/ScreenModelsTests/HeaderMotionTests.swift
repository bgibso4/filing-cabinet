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

/// The small title and subtitle fade in as the large title collapses, and are gone while it fully shows.
@Test func smallTitleFadesInAsTheLargeOneCollapses() {
    #expect(HeaderMotion.smallTitleOpacity(growth: 1) == 0)
    #expect(HeaderMotion.smallTitleOpacity(growth: 0.25) == 0.75)
    #expect(HeaderMotion.smallTitleOpacity(growth: 0) == 1)
}

/// The large title shows only as far as it has grown: a screen resting small draws none of it, so a pop back to Home
/// can't show it over Home's (phone check F1).
@Test func largeTitleFadesWithGrowth() {
    #expect(HeaderMotion.largeTitleOpacity(growth: 0) == 0)
    #expect(HeaderMotion.largeTitleOpacity(growth: 0.25) == 0.25)
    #expect(HeaderMotion.largeTitleOpacity(growth: 1) == 1)
}

@Test func shortContentStillRestsSmall() {
    // Content one viewport tall plus the large title's height always leaves room to scroll it away.
    #expect(motion.minimumContentHeight(viewport: 700) == 752)
}
