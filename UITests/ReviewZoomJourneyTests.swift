import Core
import XCTest

/// Review's pages zoom full screen, as the viewer's do.
@MainActor
final class ReviewZoomJourneyTests: XCTestCase {
    private typealias Review = AccessibilityID.Review

    override func setUp() {
        continueAfterFailure = false
    }

    /// Review zooms like the viewer: a double tap zooms the page full screen, a swipe first pans the zoomed page, and
    /// swiping on at its edge goes to the next page, as in Photos.
    func testReviewZoomedPageSwipesToTheNextPage() {
        let app = launchApp(["-FakeCamera", "3", "-FakeReader"])
        scanOnePage(in: app)
        let strip = app.descendants(matching: .any)[Review.strip]
        XCTAssertTrue(strip.appears(within: 5))
        XCTAssertEqual(strip.label, "Page 1 of 3")

        // The page is decorative (the pill names it), so it is found by where it sits: under the pill.
        let window = app.windows.firstMatch
        let pill = app.descendants(matching: .any)[Review.pagePill]
        let page = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: pill.frame.midX, dy: pill.frame.maxY + 120))
        page.doubleTap()

        // Zoomed, the first swipe pans the page rather than turning it.
        window.swipeLeft()
        XCTAssertEqual(strip.label, "Page 1 of 3", "the first swipe turned the page, so it wasn't zoomed")

        // Back to 1×, then zoomed around the trailing edge, the page rests at that edge, so one swipe turns it. A loop
        // of swipes until the strip changed overshot to page 3 on CI: a check slower than its wait let one more swipe
        // through (#64).
        page.doubleTap()
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0)).withOffset(
            CGVector(dx: 0, dy: pill.frame.maxY + 120)
        )
        .doubleTap()
        window.swipeLeft()
        XCTAssertTrue(
            strip.satisfies("label == %@", "Page 2 of 3", within: 5), "one swipe at the edge didn't turn the page")
    }
}
