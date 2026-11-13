import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private let noon = CalendarDay(year: 2026, month: 10, day: 12).date(in: utc).addingTimeInterval(12 * 3600)
private let clock = AppClock.fixed(noon, calendar: utc)

/// A search from outside the app (Find a scan) opens Search with its text in the field and its results showing.
@MainActor
@Test func initialQueryShowsResults() throws {
    let lease = ScanSummary(
        id: ScanID(),
        title: "Lease",
        collection: .documents,
        scannedAt: noon,
        expiryOverride: nil,
        pageCount: 1,
        trashedDay: nil)
    let library = FakeLibrary(scans: [lease], clock: clock)
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }

    let model = SearchModel(
        library: library,
        today: Today(clock: clock),
        clock: clock,
        history: SearchHistory(defaults: fresh.defaults),
        analytics: RecordingAnalytics(),
        initialQuery: "lease")

    #expect(model.query == "lease")
    #expect(model.state == .results)
    #expect(model.results.map(\.id) == [lease.id])
}
