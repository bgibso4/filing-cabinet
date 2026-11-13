import Core
import Library
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import Understanding
import XCTest

/// Review, option G (Review.dc.html). The sheet: before a collection (03-05, 03-09), with one (03-07), and three pages.
/// The card: reading (the loading mock's option B), and with the suggestion in (03-02, 03-03, 03-08, 12-03).
/// Reading has finished before each snapshot, so the title is the one read from page 1 (or the suggestion's). Menus and
/// alerts are not snapshotted; the journeys attach screenshots of them.
final class ReviewSnapshotTests: XCTestCase {
    /// The sheet: no suggestions.
    @MainActor
    private func review(_ pages: [CGImage], collection: BuiltInCollection? = nil) async -> ReviewView {
        let model = reviewModel(pages, suggester: FakeScanSuggester.unavailable(), suggestionsOn: false)
        await model.startReading()
        if let collection { model.choose(collection) }
        return ReviewView(model: model, onClose: {}, onRescan: {}, onSaved: { _ in })
    }

    /// The card, still reading: the model never answers within the snapshot.
    @MainActor
    private func readingCard(_ pages: [CGImage]) async -> ReviewView {
        let model = reviewModel(pages, suggester: FakeScanSuggester(filing: .never), suggestionsOn: true)
        await model.startReading()
        return ReviewView(model: model, onClose: {}, onRescan: {}, onSaved: { _ in })
    }

    /// The card once City Pharmacy's suggestion has filled it.
    @MainActor
    private func suggestedCard(_ pages: [CGImage]) async throws -> ReviewView {
        let suggester = FakeScanSuggester(filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .zero))
        let model = reviewModel(pages, suggester: suggester, suggestionsOn: true)
        await model.startReading()
        let deadline = ContinuousClock.now + Self.suggestionWait
        while model.presentation != .card(isReading: false), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.presentation, .card(isReading: false))
        return ReviewView(model: model, onClose: {}, onRescan: {}, onSaved: { _ in })
    }

    /// How long a suggestion answering at once may take to land.
    private static let suggestionWait = Duration.seconds(2)
    /// Where the shimmer and sweep are held: halfway, the band across the bar's middle and the sweep mid-page.
    private static let motionProgress = 0.5

    @MainActor
    private func reviewModel(_ pages: [CGImage], suggester: FakeScanSuggester, suggestionsOn: Bool) -> ReviewModel {
        let input = ReviewInput(pages: pages, preselected: nil, scannedAt: Fixtures.clock.now(), source: .home)
        return ReviewModel(
            input: input,
            reader: ScanReader(reader: FakeTextReader.readsCityPharmacy()),
            library: FakeLibrary(),
            clock: Fixtures.clock,
            analytics: RecordingAnalytics(),
            readingWaitLimit: .seconds(1),
            suggester: suggester,
            suggestionsOn: suggestionsOn,
            // Never passes within a snapshot: the card stays a card.
            suggestionWaitLimit: .seconds(600),
            wordsWriter: SearchWordsWriter(
                suggester: FakeScanSuggester.unavailable(), library: FakeLibrary(), backgroundTime: NoBackgroundTime())
        )
    }

    private static func variant(_ name: String) -> SnapshotConfig.Variant {
        SnapshotConfig.variants.first { $0.name == name } ?? SnapshotConfig.variants[0]
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

    // MARK: The card

    @MainActor
    func testCardReading() async throws {
        let card = await readingCard(Fixtures.scans("scan-r-pharmacy"))
        try SnapshotHost.assertScreen(
            card.environment(\.stillMotionProgress, Self.motionProgress),
            testName: "review_card_reading",
            variants: [Self.variant("light")])
    }

    /// No shimmer and no sweep: a plain bar.
    @MainActor
    func testCardReadingReduceMotion() async throws {
        let card = await readingCard(Fixtures.scans("scan-r-pharmacy"))
        try SnapshotHost.assertScreen(
            card.environment(\.forcesReduceMotion, true),
            testName: "review_card_reading_reduce_motion",
            variants: [Self.variant("light")])
    }

    /// 03-02, with the suggestion's title ("City Pharmacy receipt") where the mock says "City Pharmacy".
    @MainActor
    func testCardSuggested() async throws {
        let card = try await suggestedCard(Fixtures.scans("scan-r-pharmacy"))
        try SnapshotHost.assertScreen(card, testName: "review_card_suggested", variants: [Self.variant("light")])
    }

    /// 03-03: the page strip above the card.
    @MainActor
    func testCardSuggestedThreePages() async throws {
        let card = try await suggestedCard(Fixtures.scans("scan-r-pharmacy", "scan-r-corner", "scan-r-bluebird"))
        try SnapshotHost.assertScreen(
            card, testName: "review_card_suggested_three_pages", variants: [Self.variant("light")])
    }

    /// 03-08.
    @MainActor
    func testCardSuggestedDark() async throws {
        let card = try await suggestedCard(Fixtures.scans("scan-r-pharmacy"))
        try SnapshotHost.assertScreen(card, testName: "review_card_suggested", variants: [Self.variant("dark")])
    }

    /// 12-03: Save goes under the title and line.
    @MainActor
    func testCardAtLargestText() async throws {
        let card = try await suggestedCard(Fixtures.scans("scan-r-pharmacy"))
        try SnapshotHost.assertScreen(card, testName: "review_card_suggested", variants: [Self.variant("ax5")])
    }
}

/// Review's snapshots never save, so no words call asks for time.
private struct NoBackgroundTime: BackgroundTime {
    func begin(_ name: String, expired: @escaping @MainActor @Sendable () -> Void) -> () -> Void { {} }
}
