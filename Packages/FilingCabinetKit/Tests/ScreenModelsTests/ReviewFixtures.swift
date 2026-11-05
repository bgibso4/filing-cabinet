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
    let model: ReviewModel

    init(
        pages: [CGImage] = [page1],
        preselected: BuiltInCollection? = nil,
        reads steps: [FakeTextReader.Step] = [.page(pharmacy)],
        readingWaitLimit: Duration = .seconds(5)
    ) {
        reader = FakeTextReader(steps)
        model = ReviewModel(
            input: ReviewInput(pages: pages, preselected: preselected, scannedAt: Self.now, source: .grid),
            reader: ScanReader(reader: reader),
            library: library,
            clock: Self.clock,
            analytics: analytics,
            readingWaitLimit: readingWaitLimit
        )
    }

    /// A scan flow whose reviews read the pharmacy receipt.
    static func flow() -> ScanFlowModel {
        ScanFlowModel(
            cameraAccess: FakeCameraAccess(status: .authorized, grantsOnRequest: true),
            clock: clock,
            analytics: RecordingAnalytics(),
            makeReview: { input in
                ReviewModel(
                    input: input,
                    reader: ScanReader(reader: FakeTextReader([.page(pharmacy)])),
                    library: FakeLibrary(),
                    clock: clock,
                    analytics: RecordingAnalytics(),
                    readingWaitLimit: .seconds(5)
                )
            }
        )
    }

    /// The search text added after the save, waiting up to 5 s for it.
    func laterSearchText(for id: ScanID) async -> String? {
        let deadline = ContinuousClock.now + .seconds(5)
        while library.searchTextUpdates[id] == nil, ContinuousClock.now < deadline { await Task.yield() }
        return library.searchTextUpdates[id]
    }
}
