import Core
import Library
import ScreenModels
import Screens
import TestSupport
import Understanding
import XCTest

/// Review, option G's sheet (Review.dc.html): before a collection (03-05, 03-09), with one (03-07), and three pages.
/// Reading has finished before each snapshot, so the title is the one read from page 1. Menus and alerts are not
/// snapshotted; the journeys attach screenshots of them.
final class ReviewSnapshotTests: XCTestCase {
    @MainActor
    private func review(_ pages: [CGImage], collection: BuiltInCollection? = nil) async -> ReviewView {
        let input = ReviewInput(pages: pages, preselected: nil, scannedAt: Fixtures.clock.now(), source: .home)
        let model = ReviewModel(
            input: input,
            reader: ScanReader(reader: FakeTextReader.readsCityPharmacy()),
            library: FakeLibrary(),
            clock: Fixtures.clock,
            analytics: RecordingAnalytics(),
            readingWaitLimit: .seconds(1)
        )
        await model.startReading()
        if let collection { model.choose(collection) }
        return ReviewView(model: model, onClose: {}, onRescan: {}, onSaved: { _, _ in })
    }

    @MainActor
    func testReviewSheet() async throws {
        let pages = Fixtures.scans("scan-r-pharmacy")
        XCTAssertEqual(pages.count, 1)
        try SnapshotHost.assertScreen(await review(pages), testName: "review_sheet")
    }

    @MainActor
    func testReviewPicked() async throws {
        let pages = Fixtures.scans("scan-r-pharmacy")
        XCTAssertEqual(pages.count, 1)
        try SnapshotHost.assertScreen(await review(pages, collection: .receipts), testName: "review_picked")
    }

    @MainActor
    func testReviewThreePages() async throws {
        let pages = Fixtures.scans("scan-r-pharmacy", "scan-r-corner", "scan-r-bluebird")
        XCTAssertEqual(pages.count, 3)
        try SnapshotHost.assertScreen(await review(pages), testName: "review_three_pages")
    }
}
