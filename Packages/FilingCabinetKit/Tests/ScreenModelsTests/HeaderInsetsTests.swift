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

@Test func oneInsetSaysNothingAboutTheLargeTitle() {
    var insets = HeaderInsets()
    insets.record(170)
    #expect(insets.motion == nil)
    #expect(insets.growth(resting: .small) == 0)
    #expect(insets.growth(resting: .large) == 1)
}

@Test func theInsetsDropIsTheLargeTitlesHeight() {
    let insets = collapsed()
    #expect(insets.motion == HeaderMotion(largeHeight: 60))
    #expect(insets.isCollapsed)
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
    #expect(insets.motion == nil)
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

/// A screen that appears under a bar already collapsed (a new identity in place) learns the large title on the first
/// pull instead.
@Test func aCollapsedBarFirstThenExpandedMeasuresTheSame() {
    var insets = HeaderInsets()
    insets.record(110)
    #expect(insets.motion == nil)
    #expect(insets.growth(resting: .small) == 0)
    insets.record(140)
    insets.record(170)
    #expect(insets.motion == HeaderMotion(largeHeight: 60))
    #expect(insets.growth(resting: .small) == 1)
    insets.record(140)
    #expect(insets.growth(resting: .small) == 0.5)
    #expect(insets.minimumContentHeight(height: 800) == 750)
}

/// A screen resting large (Home) opens with the bar expanded, so the large title's measured height says where the bar
/// collapses before it ever has: the first scroll fades the small title in instead of showing it at once.
@Test func restingLargeTheMeasuredTitleFadesTheFirstScroll() {
    var insets = HeaderInsets()
    insets.record(170, atTop: true)
    insets.recordLargeTitle(height: 60)
    #expect(insets.growth(resting: .large) == 1)
    insets.record(140, atTop: false)
    #expect(insets.growth(resting: .large) == 0.5)
    insets.record(110, atTop: false)
    #expect(insets.growth(resting: .large) == 0)
}

/// The bar first lays out with the system's own large-title height (168 pt on Home), then ours (156.67 pt), both with
/// the content at its top: the later one is the expanded bar, not the larger (measured on FC iPhone 17).
@Test func restingLargeTheLatestInsetAtTheTopIsTheExpandedBar() {
    var insets = HeaderInsets()
    insets.recordLargeTitle(height: 60)
    insets.record(180, atTop: true)
    insets.record(170, atTop: true)
    #expect(insets.growth(resting: .large) == 1)
    insets.record(140, atTop: false)
    #expect(insets.growth(resting: .large) == 0.5)
}

/// Pulled past the top, the content's offset passes minus the inset; the bar is still the expanded one.
@Test func restingLargeAPullKeepsTheTitleLarge() {
    var insets = HeaderInsets()
    insets.recordLargeTitle(height: 60)
    insets.record(170, atTop: true)
    insets.record(170, atTop: true)
    #expect(insets.growth(resting: .large) == 1)
}

/// The title shrinks with the bar as it collapses; its full height is the one that counts.
@Test func theTallestMeasuredTitleCounts() {
    var insets = HeaderInsets()
    insets.record(170, atTop: true)
    insets.recordLargeTitle(height: 60)
    insets.recordLargeTitle(height: 20)
    insets.recordLargeTitle(height: 0)
    insets.record(140, atTop: false)
    #expect(insets.growth(resting: .large) == 0.5)
}

/// Resting small, the measured title isn't used: growth waits for the bar to be seen both ways, as before.
@Test func restingSmallTheMeasuredTitleIsNotUsed() {
    var insets = HeaderInsets()
    insets.record(110, atTop: true)
    insets.recordLargeTitle(height: 60)
    #expect(insets.growth(resting: .small) == 0)
    #expect(insets.motion == nil)
    #expect(!insets.isCollapsed)
}

/// Resting large, a partial first scroll is not the whole title, as the insets' drop alone would say.
@Test func restingLargeTheMeasuredTitleWinsOverAPartialScroll() {
    var insets = HeaderInsets()
    insets.record(170, atTop: true)
    insets.recordLargeTitle(height: 60)
    insets.record(155, atTop: false)
    #expect(insets.growth(resting: .large) == 0.75)
}

/// The content sits at its top when its offset is minus the inset, or less when pulled past it; rounding is allowed for.
@Test func theContentIsAtItsTopUntilItScrollsUnderTheBar() {
    #expect(HeaderInsets.isAtTop(inset: 170, contentOffset: -170))
    #expect(HeaderInsets.isAtTop(inset: 170, contentOffset: -240))
    #expect(HeaderInsets.isAtTop(inset: 156.67, contentOffset: -156.66))
    #expect(!HeaderInsets.isAtTop(inset: 146.67, contentOffset: -142.67))
}

/// Scrolled back down, the content reaches its top while the bar is still collapsed and expands with the pull: the bar
/// seen before the first scroll stays the expanded one, so the small title fades out again rather than vanishing.
@Test func restingLargeScrollingBackFadesTheTitleOut() {
    var insets = HeaderInsets()
    insets.recordLargeTitle(height: 60)
    insets.record(170, atTop: true)
    insets.record(140, atTop: false)
    insets.record(110, atTop: false)
    insets.record(110, atTop: true)
    #expect(insets.growth(resting: .large) == 0)
    insets.record(140, atTop: true)
    #expect(insets.growth(resting: .large) == 0.5)
    insets.record(170, atTop: true)
    #expect(insets.growth(resting: .large) == 1)
}
