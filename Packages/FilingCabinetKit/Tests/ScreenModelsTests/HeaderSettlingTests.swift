import CoreGraphics
import Testing

@testable import ScreenModels

/// Records the bar's inset, with the content at its top or not, and returns the scroll the settling asks for.
private func report(
    _ settling: inout HeaderSettling, _ insets: inout HeaderInsets, inset: CGFloat, atTop: Bool = false
) -> HeaderScroll? {
    insets.record(inset, atTop: atTop)
    return settling.target(insets: insets, inset: inset)
}

@Test func restingSmallCollapsesTheBarThenScrollsBackToTheTop() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    #expect(report(&settling, &insets, inset: 170) == .content(offset: 170))
    #expect(report(&settling, &insets, inset: 110) == .content(offset: 0))
    #expect(report(&settling, &insets, inset: 110) == nil)
    // A pull afterwards is the person's: nothing more is asked.
    #expect(report(&settling, &insets, inset: 170) == nil)
}

/// The scroll lands a report before the bar collapses (seen on the simulator): landing alone settles nothing.
@Test func waitsForTheInsetToDrop() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    _ = report(&settling, &insets, inset: 170)
    #expect(report(&settling, &insets, inset: 170) == nil)
    #expect(report(&settling, &insets, inset: 110) == .content(offset: 0))
}

@Test func restingLargeOrNotScrollingAsksNothing() {
    var large = HeaderSettling(rest: .large, scrolls: true)
    var still = HeaderSettling(rest: .small, scrolls: false)
    var insets = HeaderInsets()
    #expect(report(&large, &insets, inset: 170) == nil)
    #expect(report(&still, &insets, inset: 170) == nil)
}

@Test func aZeroInsetAsksNothing() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    #expect(report(&settling, &insets, inset: 0) == nil)
    #expect(report(&settling, &insets, inset: 170) == .content(offset: 170))
}

/// Trash filling up while on screen: it rested large and still, and now rests small.
@Test func changingToRestSmallSettlesAgainFromTheLastInset() {
    var settling = HeaderSettling(rest: .large, scrolls: false)
    var insets = HeaderInsets()
    #expect(report(&settling, &insets, inset: 170) == nil)
    settling.update(rest: .small, scrolls: true)
    #expect(settling.target(insets: insets, inset: 170) == .content(offset: 170))
    #expect(report(&settling, &insets, inset: 110) == .content(offset: 0))
}

/// Back to small with the bar already collapsed (after a scroll up while large): nothing to undo.
@Test func changingToRestSmallUnderACollapsedBarAsksNothing() {
    var settling = HeaderSettling(rest: .large, scrolls: true)
    var insets = HeaderInsets()
    _ = report(&settling, &insets, inset: 170)
    _ = report(&settling, &insets, inset: 110)
    settling.update(rest: .small, scrolls: true)
    #expect(settling.target(insets: insets, inset: 110) == nil)
    #expect(report(&settling, &insets, inset: 170) == nil)
}

@Test func anUnchangedRestDoesNotSettleAgain() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    _ = report(&settling, &insets, inset: 170)
    _ = report(&settling, &insets, inset: 110)
    settling.update(rest: .small, scrolls: true)
    #expect(settling.target(insets: insets, inset: 110) == nil)
}

/// A grid emptied on screen while it rested small: the bar expands, as a pull would, to show the large title (B5).
@Test func changingToRestLargeUnderACollapsedBarExpandsIt() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    _ = report(&settling, &insets, inset: 170)
    _ = report(&settling, &insets, inset: 110)
    settling.update(rest: .large, scrolls: false)
    #expect(settling.target(insets: insets, inset: 110) == .scrollView(offset: -170))
    #expect(report(&settling, &insets, inset: 170) == nil)
}

/// Emptied with the large title already pulled out: nothing to do.
@Test func changingToRestLargeUnderAnExpandedBarAsksNothing() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    _ = report(&settling, &insets, inset: 170)
    _ = report(&settling, &insets, inset: 110)
    _ = report(&settling, &insets, inset: 170)
    settling.update(rest: .large, scrolls: false)
    #expect(settling.target(insets: insets, inset: 170) == nil)
}

/// An empty grid pushed from Home (phone check F6, measured in the simulator): the bar opens at Home's large title
/// height (164.67), then collapses by itself (116) with the content still at its top. Until the person has scrolled, a
/// collapse is the system's, and is expanded again.
@Test func restingLargeAndStillExpandsABarThatCollapsesByItself() {
    var settling = HeaderSettling(rest: .large, scrolls: false)
    var insets = HeaderInsets()
    insets.largeTitleHeight = 68.67
    // The arrival's pull (`restingLargeANewScreenPullsOnItsFirstReport`): the collapse here is one it didn't prevent.
    #expect(report(&settling, &insets, inset: 164.67, atTop: true) == .pullDuringPush(offset: -(164.67 + 68.67)))
    #expect(report(&settling, &insets, inset: 116, atTop: true) == .scrollView(offset: -164.67))
    #expect(report(&settling, &insets, inset: 184.67, atTop: true) == nil)
}

/// The same push at an accessibility text size, where an empty grid scrolls (review I1): still the system's collapse.
@Test func restingLargeAndScrollingExpandsABarThatCollapsesBeforeAnyScroll() {
    var settling = HeaderSettling(rest: .large, scrolls: true)
    var insets = HeaderInsets()
    insets.largeTitleHeight = 68.67
    // The arrival's pull (`restingLargeANewScreenPullsOnItsFirstReport`): the collapse here is one it didn't prevent.
    #expect(report(&settling, &insets, inset: 164.67, atTop: true) == .pullDuringPush(offset: -(164.67 + 68.67)))
    #expect(report(&settling, &insets, inset: 116, atTop: true) == .scrollView(offset: -164.67))
}

/// The bar laying out again a few points shorter (168, then 164.67, measured under the old titles): not a collapse.
@Test func restingLargeTheBarLayingOutShorterIsNoCollapse() {
    var settling = HeaderSettling(rest: .large, scrolls: true)
    var insets = HeaderInsets()
    insets.largeTitleHeight = 48.67
    _ = report(&settling, &insets, inset: 168, atTop: true)  // the arrival's pull
    #expect(report(&settling, &insets, inset: 164.67, atTop: true) == nil)
}

/// An empty grid at an accessibility size rests large and scrolls: once the person has scrolled, a collapse is theirs,
/// and stays.
@Test func restingLargeACollapseAfterAScrollStays() {
    var settling = HeaderSettling(rest: .large, scrolls: true)
    var insets = HeaderInsets()
    insets.largeTitleHeight = 48.67
    _ = report(&settling, &insets, inset: 164.67, atTop: true)
    #expect(report(&settling, &insets, inset: 140) == nil)
    #expect(report(&settling, &insets, inset: 116) == nil)
    #expect(report(&settling, &insets, inset: 164.67, atTop: true) == nil)
    #expect(report(&settling, &insets, inset: 116) == nil)
}

/// A pull down and release on an unscrolled screen stays at its top all the way, so only the touch itself ends the watch
/// (review N1): the bar the person pulled taller and let go of is theirs, and nothing snaps it open.
@Test func restingLargeATouchEndsTheWatch() {
    var settling = HeaderSettling(rest: .large, scrolls: true)
    var insets = HeaderInsets()
    insets.largeTitleHeight = 48.67
    _ = report(&settling, &insets, inset: 164.67, atTop: true)
    settling.stopWatching()
    #expect(report(&settling, &insets, inset: 200, atTop: true) == nil)
    #expect(report(&settling, &insets, inset: 116, atTop: true) == nil)
}

/// Covered by a pushed screen, its bar collapses with the shared bar (seen under -UITest): the watch has ended by then
/// (review N2), so it asks for no scroll off screen.
@Test func restingLargeACoveredScreenAsksNothing() {
    var settling = HeaderSettling(rest: .large, scrolls: true)
    var insets = HeaderInsets()
    insets.largeTitleHeight = 48.67
    _ = report(&settling, &insets, inset: 168, atTop: true)
    _ = report(&settling, &insets, inset: 164.67, atTop: true)
    settling.stopWatching()
    #expect(report(&settling, &insets, inset: 116, atTop: true) == nil)
}

/// Stopping the watch leaves a live change alone: a grid emptied on screen still expands its collapsed bar once.
@Test func stoppingTheWatchKeepsALiveChangeToLarge() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    _ = report(&settling, &insets, inset: 170)
    _ = report(&settling, &insets, inset: 110)
    settling.stopWatching()
    settling.update(rest: .large, scrolls: false)
    #expect(settling.target(insets: insets, inset: 110) == .scrollView(offset: -170))
}

/// An empty grid pushed from Home (plan 3, E9, measured): it first lays out under Home's shorter bar (168), and UIKit
/// collapses the bar for the whole push unless the content is above its top by then. So a new screen resting large
/// pulls its content down by a large title's height on its first report, and the bar opens to its own height (188.33).
@Test func restingLargeANewScreenPullsOnItsFirstReport() {
    var settling = HeaderSettling(rest: .large, scrolls: false)
    var insets = HeaderInsets()
    insets.largeTitleHeight = 41
    #expect(report(&settling, &insets, inset: 0) == nil)
    #expect(report(&settling, &insets, inset: 168, atTop: true) == .pullDuringPush(offset: -209))
    #expect(report(&settling, &insets, inset: 188.33, atTop: true) == nil)
}
