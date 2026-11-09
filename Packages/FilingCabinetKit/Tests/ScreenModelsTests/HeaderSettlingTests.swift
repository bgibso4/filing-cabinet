import CoreGraphics
import Testing

@testable import ScreenModels

/// Records the bar's inset and returns the scroll the settling asks for.
private func report(_ settling: inout HeaderSettling, _ insets: inout HeaderInsets, inset: CGFloat) -> HeaderScroll? {
    insets.record(inset)
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
/// height (164.67), then collapses by itself (116), and nothing touching the screen can bring it back. Content that
/// doesn't scroll can't collapse the bar, so a collapse seen there is always expanded again.
@Test func restingLargeAndStillExpandsABarThatCollapsesByItself() {
    var settling = HeaderSettling(rest: .large, scrolls: false)
    var insets = HeaderInsets()
    #expect(report(&settling, &insets, inset: 164.67) == nil)
    #expect(report(&settling, &insets, inset: 116) == .scrollView(offset: -164.67))
    #expect(report(&settling, &insets, inset: 184.67) == nil)
}

/// Home rests large and scrolls: a collapse there is the person's scroll, and stays.
@Test func restingLargeAndScrollingLeavesACollapseAlone() {
    var settling = HeaderSettling(rest: .large, scrolls: true)
    var insets = HeaderInsets()
    _ = report(&settling, &insets, inset: 164.67)
    #expect(report(&settling, &insets, inset: 116) == nil)
}
