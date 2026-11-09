import CoreGraphics
import Testing

@testable import ScreenModels

/// The bar opens at 170 pt and collapses to 110 pt: a 60 pt large title.
private func collapsed() -> HeaderInsets {
    var insets = HeaderInsets()
    insets.record(170)
    insets.record(110)
    return insets
}

@Test func theFirstInsetIsTheExpandedBar() {
    var insets = HeaderInsets()
    insets.record(170)
    #expect(insets.motion == nil)
    #expect(!insets.hasCollapsed)
    #expect(insets.growth(resting: .small) == 0)
    #expect(insets.growth(resting: .large) == 1)
}

@Test func theInsetsDropIsTheLargeTitlesHeight() {
    let insets = collapsed()
    #expect(insets.hasCollapsed)
    #expect(insets.motion == HeaderMotion(largeHeight: 60))
    #expect(insets.growth(resting: .small) == 0)
}

@Test func growthFollowsTheInsetBetweenTheTwo() {
    var insets = collapsed()
    insets.record(140)
    #expect(insets.growth(resting: .small) == 0.5)
    insets.record(170)
    #expect(insets.growth(resting: .small) == 1)
}

@Test func aZeroInsetIsIgnored() {
    var insets = HeaderInsets()
    insets.record(0)
    insets.record(170)
    insets.record(0)
    #expect(!insets.hasCollapsed)
    #expect(insets.growth(resting: .large) == 1)
}

@Test func untilItCollapsesTheContentIsAsTallAsTheScreenUnderTheStatusBar() {
    var insets = HeaderInsets()
    insets.record(170)
    #expect(insets.minimumContentHeight(height: 800) == 800)
}

@Test func onceCollapsedTheContentIsTheCollapsedViewportPlusTheLargeTitle() {
    #expect(collapsed().minimumContentHeight(height: 800) == 750)
}
