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

@MainActor
@Test func searchFindsANewScanByWordAfterUpdate() throws {
    let license = ScanSummary(
        id: ScanID(),
        title: "Driver’s license",
        collection: .wallet,
        scannedAt: noon,
        expiryOverride: nil,
        pageCount: 1,
        trashedDay: nil)
    let library = FakeLibrary(scans: [license], clock: clock)
    library.updateSearchText("Sample State\nDL 123", for: license.id)
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let model = SearchModel(
        library: library,
        today: Today(clock: clock),
        clock: clock,
        history: SearchHistory(defaults: fresh.defaults),
        analytics: RecordingAnalytics())

    model.query = "ID"
    #expect(model.results.isEmpty)
    library.updateSearchWords(["ID", "driver license"], version: 1, for: license.id)
    let result = try #require(model.results.first)
    #expect(result.secondLine == .hiddenWord(query: "ID"))
    #expect(result.accessibilityLabel == "Driver’s license, Wallet, October 12, Matches ID")

    // Page text that says it too shows its line, not the sparkle.
    library.updateSearchText("Photo ID", for: license.id)
    let withText = try #require(model.results.first)
    guard case .snippet(let line, _) = withText.secondLine else {
        Issue.record("expected a snippet, got \(withText.secondLine)")
        return
    }
    #expect(line == "Photo ID")
}
