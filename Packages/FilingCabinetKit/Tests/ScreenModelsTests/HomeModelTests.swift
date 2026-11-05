import Core
import Foundation
import Library
import Synchronization
import Testing

@testable import ScreenModels
@testable import TestSupport

/// A clock the test moves by hand.
nonisolated private final class MovableNow: Sendable {
    private let date: Mutex<Date>

    init(_ date: Date) {
        self.date = Mutex(date)
    }

    var now: Date { date.withLock { $0 } }

    func set(_ newDate: Date) {
        date.withLock { $0 = newDate }
    }
}

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private let noon = CalendarDay(year: 2026, month: 10, day: 12).date(in: utc).addingTimeInterval(12 * 3600)

private func scans(_ collection: BuiltInCollection, _ count: Int, daysAgo: Int = 0) -> [ScanSummary] {
    (0..<count).map { _ in
        ScanSummary(
            id: ScanID(),
            title: "Scan",
            collection: collection,
            scannedAt: noon.addingTimeInterval(Double(-daysAgo) * 86_400),
            expiryOverride: nil,
            pageCount: 1)
    }
}

private func model(_ summaries: [ScanSummary], clock: MovableNow = MovableNow(noon)) -> HomeModel {
    let appClock = AppClock(now: { clock.now }, calendar: utc, locale: Locale(identifier: "en_US"))
    return HomeModel(library: FakeLibrary(scans: summaries), today: Today(clock: appClock), calendar: utc)
}

@Test func emptyLibraryShowsDescriptionsAndNoViews() {
    let home = model([])
    #expect(home.isEmpty)
    #expect(home.rows.map(\.name) == ["Wallet", "Receipts", "Notes", "Documents", "Throwaways"])
    #expect(
        home.rows.map(\.detail) == [
            .subtitle("IDs and cards · Kept forever"), .subtitle("Purchase receipts · 3 months"),
            .subtitle("Handwritten notes · Kept forever"), .subtitle("Forms and letters · Kept forever"),
            .subtitle("Short-lived scraps · 1 week"),
        ])
    #expect(home.viewRows.isEmpty)
}

@Test func countsPerCollectionAndViews() {
    let all =
        scans(.wallet, 6) + scans(.receipts, 23) + scans(.notes, 41) + scans(.documents, 18) + scans(.throwaways, 3)
    let home = model(all)
    #expect(!home.isEmpty)
    #expect(home.rows.map(\.detail) == [.count(6), .count(23), .count(41), .count(18), .count(3)])
    #expect(home.viewRows.map(\.name) == ["Recent", "All Scans"])
    #expect(home.viewRows.map(\.kind) == [.recent, .all])
    #expect(home.viewRows.map(\.count) == [nil, 91])
}

@Test func expiredScansAreNotCounted() {
    // Throwaways last a week: a scan 7 days old is expired, one 6 days old is on its last day.
    let home = model(scans(.throwaways, 2, daysAgo: 7) + scans(.throwaways, 1, daysAgo: 6) + scans(.wallet, 1))
    #expect(home.rows.last?.detail == .count(1))
    #expect(home.viewRows.last?.count == 2)
}

@Test func anOnlyExpiredLibraryShowsTheFirstLaunchRows() {
    let home = model(scans(.throwaways, 2, daysAgo: 30))
    #expect(home.isEmpty)
    #expect(home.viewRows.isEmpty)
    #expect(home.rows.first?.detail == .subtitle("IDs and cards · Kept forever"))
}

@Test func countsUpdateWhenTodayMovesPastAnExpiry() {
    let clock = MovableNow(noon)
    let today = Today(clock: AppClock(now: { clock.now }, calendar: utc, locale: Locale(identifier: "en_US")))
    let home = HomeModel(
        library: FakeLibrary(scans: scans(.throwaways, 2) + scans(.wallet, 1)), today: today, calendar: utc)
    #expect(home.rows.last?.detail == .count(2))

    clock.set(noon.addingTimeInterval(7 * 86_400))
    today.refresh()
    #expect(home.rows.last?.detail == .count(0))
    #expect(home.viewRows.last?.count == 1)
}
