import Core
import CoreGraphics
import Foundation
import Library
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

/// Shared by the review tests: one Oct 12, 2026 scan of synthetic pages, read by a scripted reader.
@MainActor
struct ReviewHarness {
    static var newYork: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }

    /// Oct 12, 2026, 8:00 in New York.
    static let now = Date(timeIntervalSince1970: 1_791_806_400)
    static let clock = AppClock.fixed(now, calendar: newYork)
    static let page1 = SyntheticPages.page(lines: [("ONE", 40)], size: CGSize(width: 60, height: 80))
    static let page2 = SyntheticPages.page(lines: [("TWO", 40)], size: CGSize(width: 60, height: 80))
    static let page3 = SyntheticPages.page(lines: [("THREE", 40)], size: CGSize(width: 60, height: 80))

    static let pharmacy = PageText(lines: [
        TextLine(text: "CITY PHARMACY", box: CGRect(x: 0.08, y: 0.06, width: 0.6, height: 0.05)),
        TextLine(text: "TOTAL 12.40", box: CGRect(x: 0.08, y: 0.15, width: 0.25, height: 0.02)),
    ])
    static let market = PageText(lines: [
        TextLine(text: "CORNER MARKET", box: CGRect(x: 0.08, y: 0.06, width: 0.6, height: 0.05))
    ])

    let analytics = RecordingAnalytics()
    let library = FakeLibrary()
    let reader: FakeTextReader
    let suggester: FakeScanSuggester
    let backgroundTime = FakeBackgroundTime()
    let model: ReviewModel

    /// Suggestions are off unless `suggestionsOn` says otherwise, so a review behaves as before Plan 5.
    init(
        pages: [CGImage] = [page1],
        preselected: BuiltInCollection? = nil,
        reads steps: [FakeTextReader.Step] = [.page(pharmacy)],
        readingWaitLimit: Duration = .seconds(5),
        suggester: FakeScanSuggester = .unavailable(),
        suggestionsOn: Bool = false,
        suggestionWaitLimit: Duration = .seconds(5)
    ) {
        reader = FakeTextReader(steps)
        self.suggester = suggester
        model = ReviewModel(
            input: ReviewInput(pages: pages, preselected: preselected, scannedAt: Self.now, source: .grid),
            reader: ScanReader(reader: reader),
            library: library,
            clock: Self.clock,
            analytics: analytics,
            readingWaitLimit: readingWaitLimit,
            suggester: suggester,
            suggestionsOn: suggestionsOn,
            suggestionWaitLimit: suggestionWaitLimit,
            wordsWriter: SearchWordsWriter(suggester: suggester, library: library, backgroundTime: backgroundTime)
        )
    }

    /// A scan flow whose reviews read the pharmacy receipt.
    static func flow() -> ScanFlowModel {
        ScanFlowModel(
            cameraAccess: FakeCameraAccess(status: .authorized, grantsOnRequest: true),
            clock: clock,
            analytics: RecordingAnalytics(),
            suggester: FakeScanSuggester.unavailable(),
            suggestionsOn: { true },
            makeReview: { input in
                ReviewModel(
                    input: input,
                    reader: ScanReader(reader: FakeTextReader([.page(pharmacy)])),
                    library: FakeLibrary(),
                    clock: clock,
                    analytics: RecordingAnalytics(),
                    readingWaitLimit: .seconds(5),
                    suggester: FakeScanSuggester.unavailable(),
                    suggestionsOn: true,
                    suggestionWaitLimit: .seconds(5),
                    wordsWriter: SearchWordsWriter(
                        suggester: FakeScanSuggester.unavailable(),
                        library: FakeLibrary(),
                        backgroundTime: FakeBackgroundTime()
                    )
                )
            }
        )
    }

    /// Waits up to `limit` for `done`, checking every few milliseconds; true if it came.
    @discardableResult
    static func eventually(within limit: Duration = .seconds(5), _ done: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + limit
        while !done(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))  // only ends early when the test is cancelled
        }
        return done()
    }

    /// The search text added after the save, waiting up to `limit` for it.
    func laterSearchText(for id: ScanID, within limit: Duration = .seconds(5)) async -> String? {
        let deadline = ContinuousClock.now + limit
        while library.searchTextUpdates[id] == nil, ContinuousClock.now < deadline { await Task.yield() }
        return library.searchTextUpdates[id]
    }
}
