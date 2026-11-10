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
    #expect(insets.largeHeight == nil)
    #expect(!insets.isCollapsed)
}

@Test func theInsetsDropIsTheLargeTitlesHeight() {
    let insets = collapsed()
    #expect(insets.largeHeight == 60)
    #expect(insets.isCollapsed)
    #expect(insets.largest == 170)
}

@Test func aZeroInsetIsIgnored() {
    var insets = HeaderInsets()
    insets.record(0)
    insets.record(170)
    insets.record(0)
    #expect(insets.largeHeight == nil)
    #expect(insets.largest == 170)
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
    #expect(insets.largeHeight == nil)
    insets.record(140)
    insets.record(170)
    #expect(insets.largeHeight == 60)
    #expect(!insets.isCollapsed)
    #expect(insets.minimumContentHeight(height: 800) == 750)
}

/// A collapse counts once the bar is down by more than half the large title: not the bar laying out a few points
/// shorter.
@Test func aCollapseIsMoreThanHalfTheLargeTitle() {
    var insets = HeaderInsets()
    insets.largeTitleHeight = 41
    insets.record(170, atTop: true)
    insets.record(166, atTop: true)
    #expect(!insets.hasCollapsedTheLargeTitle)
    insets.record(118, atTop: true)
    #expect(insets.hasCollapsedTheLargeTitle)
}

/// The content sits at its top when its offset is minus the inset, or less when pulled past it; rounding is allowed for.
@Test func theContentIsAtItsTopUntilItScrollsUnderTheBar() {
    #expect(HeaderInsets.isAtTop(inset: 170, contentOffset: -170))
    #expect(HeaderInsets.isAtTop(inset: 170, contentOffset: -240))
    #expect(HeaderInsets.isAtTop(inset: 156.67, contentOffset: -156.66))
    #expect(!HeaderInsets.isAtTop(inset: 146.67, contentOffset: -142.67))
}

/// The person has scrolled once the content leaves its top after resting there; a first report away from the top (the
/// bar still laying out) isn't a scroll.
@Test func scrollingIsLeavingTheTopAfterRestingThere() {
    var insets = HeaderInsets()
    insets.record(170, atTop: false)
    #expect(!insets.hasScrolled)
    insets.record(170, atTop: true)
    #expect(!insets.hasScrolled)
    insets.record(140, atTop: false)
    #expect(insets.hasScrolled)
}
