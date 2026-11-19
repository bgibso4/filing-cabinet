import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
private let noon = oct12.date(in: utc).addingTimeInterval(12 * 3600)
private let clock = AppClock.fixed(noon, calendar: utc)

private func day(_ offset: Int) -> CalendarDay { oct12.adding(days: offset, in: utc) }

/// A scan that entered (or enters) Trash on its own on `entry`: its last day is the day before.
private func expired(entering entry: CalendarDay, trashedDay: CalendarDay? = nil) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: "Synthetic",
        collection: .throwaways,
        scannedAt: noon.addingTimeInterval(-40 * 86_400),
        expiryOverride: .lastDay(entry.adding(days: -1, in: utc)),
        pageCount: 1,
        trashedDay: trashedDay)
}

@MainActor
private struct BannerHarness {
    let preferences: AppPreferences
    let library: FakeLibrary
    let banner: CleanupBanner
    private let fresh: FreshDefaults

    /// `seenThrough` nil leaves no stored day: the first run.
    init(
        _ scans: [ScanSummary],
        seenThrough: CalendarDay?,
        notesOn: Bool = true
    ) throws {
        fresh = try FreshDefaults()
        preferences = AppPreferences(defaults: fresh.defaults)
        preferences.cleanupSeenThrough = seenThrough
        preferences.notificationsOn = notesOn
        library = FakeLibrary(scans: scans, clock: clock)
        banner = CleanupBanner(
            library: library,
            today: Today(clock: clock),
            preferences: preferences)
    }

    func cleanUp() { fresh.cleanUp() }
}

@MainActor
@Test func countsNaturalEntriesSinceLastSeen() async throws {
    let harness = try BannerHarness(
        [
            expired(entering: day(-6)), expired(entering: day(-5)), expired(entering: day(-4)),
            expired(entering: day(0)),
        ],
        seenThrough: day(-5))
    defer { harness.cleanUp() }
    // Entered after Oct 7 and by today: the Oct 8 and Oct 12 ones.
    #expect(harness.banner.text == "2 scans moved to Trash")
}

@MainActor
@Test func oneScanIsSingular() async throws {
    let harness = try BannerHarness([expired(entering: day(-1))], seenThrough: day(-2))
    defer { harness.cleanUp() }
    #expect(harness.banner.text == "1 scan moved to Trash")
}

@MainActor
/// A note may not have arrived (it came due with the app open, or iOS held it back), so Home says it too.
@Test func shownWhenNotesAreOn() async throws {
    let harness = try BannerHarness([expired(entering: day(-1))], seenThrough: day(-2))
    defer { harness.cleanUp() }
    #expect(harness.banner.text == "1 scan moved to Trash")
}

@MainActor
@Test func shownWhenNotesAreTurnedOff() async throws {
    let harness = try BannerHarness([expired(entering: day(-1))], seenThrough: day(-2), notesOn: false)
    defer { harness.cleanUp() }
    #expect(harness.banner.text == "1 scan moved to Trash")
}

@MainActor
@Test func firstRunStartsAtToday() async throws {
    let harness = try BannerHarness([expired(entering: day(0))], seenThrough: nil)
    defer { harness.cleanUp() }
    #expect(harness.preferences.cleanupSeenThrough == oct12)
    #expect(harness.banner.text == nil)
}

@MainActor
@Test func clearHidesIt() async throws {
    let harness = try BannerHarness([expired(entering: day(-1))], seenThrough: day(-2))
    defer { harness.cleanUp() }
    #expect(harness.banner.text != nil)

    harness.banner.clear()

    #expect(harness.banner.text == nil)
    #expect(harness.preferences.cleanupSeenThrough == oct12)
}

@MainActor
@Test func manualTrashDoesNotCount() async throws {
    // Moved to Trash by hand yesterday, though its own last day would have sent it there anyway.
    let harness = try BannerHarness(
        [expired(entering: day(-1), trashedDay: day(-1))], seenThrough: day(-2))
    defer { harness.cleanUp() }
    #expect(harness.banner.text == nil)
}

@MainActor
@Test func deletedScansNoLongerCount() async throws {
    // Entered on its own 31 days ago, so it is gone from Trash.
    let harness = try BannerHarness([expired(entering: day(-30))], seenThrough: day(-40))
    defer { harness.cleanUp() }
    #expect(harness.banner.text == nil)
}

@MainActor
@Test func lifespanChangeThatLeavesTheEntryDayStillCounts() async throws {
    // Its own last day sent it to Trash, so no lifespan moves its entry day: it is still news.
    let harness = try BannerHarness([expired(entering: day(-1))], seenThrough: day(-2))
    defer { harness.cleanUp() }

    try harness.library.setLifespan(.year, for: .throwaways)
    try harness.library.setLifespan(.week, for: .receipts)

    #expect(harness.library.scans.first?.trashedDay == nil)
    #expect(harness.banner.text == "1 scan moved to Trash")
}
