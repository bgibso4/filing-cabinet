import Core
import XCTest

// MARK: Many pages

/// Kept out of `ScanJourneyTests.swift` for its length.
extension ScanJourneyTests {
    /// #119: a strip of many pages is wider than the screen. It stays inside the screen, and so does everything above
    /// it: the strip once made the whole top of review as wide as itself, pushing Rescan off the right edge.
    func testManyPagesKeepReviewOnScreen() {
        let review = AccessibilityID.Review.self
        let app = launchApp(["-FakeCamera", "20", "-FakeReader", "-FixedDate", "2026-10-12"])
        scanOnePage(in: app)
        let strip = app.descendants(matching: .any)[review.strip]
        XCTAssertTrue(strip.appears(within: 10))
        XCTAssertEqual(strip.label, "Page 1 of 20")
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(strip.frame), "strip \(strip.frame) in \(screen)")
        for id in [review.close, review.pagePill, review.rescan] {
            let frame = app.descendants(matching: .any)[id].frame
            XCTAssertTrue(screen.contains(frame), "\(id) \(frame) in \(screen)")
        }
    }
}
