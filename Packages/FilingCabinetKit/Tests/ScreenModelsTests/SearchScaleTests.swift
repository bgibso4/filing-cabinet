import Core
import Foundation
import Library
import Synchronization
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
private let noon = oct12.date(in: utc).addingTimeInterval(12 * 3600)
private let clock = AppClock.fixed(noon, calendar: utc)

/// E3's guard, structural so it never flakes on a slow CI machine: one pass visits each scan once, and a filter change
/// filters the last pass's matches rather than matching again. The pass's speed is read from the Search signpost.
@MainActor
@Test func matchingVisitsEachScanOnce() throws {
    let count = 2_000
    let collections = BuiltInCollection.allCases
    let scans = (0..<count).map { index in
        ScanSummary(
            id: ScanID(),
            title: "Scan \(index)",
            collection: collections[index % collections.count],
            scannedAt: noon.addingTimeInterval(Double(-index) * 60),
            expiryOverride: nil,
            pageCount: 1,
            trashedDay: nil)
    }
    let library = FakeLibrary(scans: scans, clock: clock)
    for scan in scans {
        library.updateSearchText("Renewal notice for \(scan.title)", for: scan.id)
        library.updateSearchWords(
            ["ID", "driver license", "card", "identity", "wallet", "permit", "state", "photo"],
            version: 1,
            for: scan.id)
    }
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let visits = Mutex(0)
    let model = SearchModel(
        library: library,
        today: Today(clock: clock),
        clock: clock,
        history: SearchHistory(defaults: fresh.defaults),
        analytics: RecordingAnalytics(),
        matching: { title, text, words, terms in
            visits.withLock { $0 += 1 }
            return SearchMatch.match(title: title, text: text, words: words, terms: terms)
        })

    model.query = "renew"
    #expect(model.results.count == count / collections.count * collections.count)
    #expect(visits.withLock { $0 } == count)

    // Reading again, with a filter, or another filter, matches nothing again.
    _ = model.results
    model.filter = collections[0]
    #expect(!model.results.isEmpty)
    model.filter = collections[1]
    _ = model.header
    #expect(visits.withLock { $0 } == count)

    // A new query is one more pass over each scan, no more.
    model.query = "renewal notice"
    _ = model.results
    #expect(visits.withLock { $0 } == 2 * count)
}
