import CoreGraphics
import Testing

@testable import ScreenModels

/// Records the bar's inset and returns the scroll the settling asks for.
private func report(_ settling: inout HeaderSettling, _ insets: inout HeaderInsets, inset: CGFloat) -> CGFloat? {
    insets.record(inset)
    return settling.target(insets: insets, inset: inset)
}

@Test func restingSmallCollapsesTheBarThenScrollsBackToTheTop() {
    var settling = HeaderSettling(rest: .small, scrolls: true)
    var insets = HeaderInsets()
    #expect(report(&settling, &insets, inset: 170) == 170)
    #expect(report(&settling, &insets, inset: 110) == 0)
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
    #expect(report(&settling, &insets, inset: 110) == 0)
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
    #expect(report(&settling, &insets, inset: 170) == 170)
}

/// Trash filling up while on screen: it rested large and still, and now rests small.
@Test func changingToRestSmallSettlesAgainFromTheLastInset() {
    var settling = HeaderSettling(rest: .large, scrolls: false)
    var insets = HeaderInsets()
    #expect(report(&settling, &insets, inset: 170) == nil)
    settling.update(rest: .small, scrolls: true)
    #expect(settling.target(insets: insets, inset: 170) == 170)
    #expect(report(&settling, &insets, inset: 110) == 0)
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
