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
    model(FakeLibrary(scans: summaries), clock: clock)
}

private func model(_ library: FakeLibrary, clock: MovableNow = MovableNow(noon)) -> HomeModel {
    let appClock = AppClock(now: { clock.now }, calendar: utc, locale: Locale(identifier: "en_US"))
    return HomeModel(library: library, today: Today(clock: appClock), calendar: utc)
}

private func save(_ collection: BuiltInCollection, to library: FakeLibrary) async throws {
    try await library.save(
        ScanDraft(
            id: ScanID(),
            title: "New",
            collection: collection,
            scannedAt: noon,
            expiryOverride: nil,
            pages: [],
            searchText: ""
        ))
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
    #expect(home.viewRows.map(\.name) == ["Recent", "All Scans", "Trash"])
    #expect(home.viewRows.map(\.kind) == [.recent, .all, .trash])
    // An empty Trash shows no number.
    #expect(home.viewRows.map(\.count) == [nil, 91, nil])
}

@Test func expiredScansAreNotCounted() {
    // Throwaways last a week: a scan 7 days old is expired, one 6 days old is on its last day.
    let home = model(scans(.throwaways, 2, daysAgo: 7) + scans(.throwaways, 1, daysAgo: 6) + scans(.wallet, 1))
    #expect(home.rows.last?.detail == .count(1))
    #expect(home.viewRows[1].count == 2)
}

/// Throwaways expire after a week and leave Trash 30 days later: 40 days old, they are gone.
@Test func anOnlyExpiredLibraryShowsTheFirstLaunchRows() {
    let home = model(scans(.throwaways, 2, daysAgo: 40))
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
    #expect(home.viewRows[1].count == 1)
}

// MARK: Trash

/// Expired scans enter Trash on their own; a scan moved there has a Trash day.
@Test func trashRowShowsItsCount() {
    let moved = scans(.wallet, 1).map { scan in
        var scan = scan
        scan.trashedDay = CalendarDay(year: 2026, month: 10, day: 10)
        return scan
    }
    let home = model(scans(.receipts, 3) + scans(.throwaways, 2, daysAgo: 8) + moved)
    #expect(home.viewRows.map(\.kind) == [.recent, .all, .trash])
    #expect(home.viewRows.map(\.name) == ["Recent", "All Scans", "Trash"])
    #expect(home.viewRows.map(\.count) == [nil, 3, 3])
}

/// M7: with every scan in Trash, Home keeps the first-launch rows and shows only the Trash row.
@Test func allInTrashShowsOnlyTheTrashRow() {
    let home = model(scans(.throwaways, 2, daysAgo: 10))
    #expect(home.isEmpty)
    #expect(home.rows.first?.detail == .subtitle("IDs and cards · Kept forever"))
    #expect(home.viewRows.map(\.kind) == [.trash])
    #expect(home.viewRows.map(\.count) == [2])
}

// MARK: Holding while the capture layer is up (P5)

@Test func whileHeldHomeShowsTheLibraryAsItWasAndCatchesUpOnRelease() async throws {
    let library = FakeLibrary(scans: scans(.receipts, 2))
    let home = model(library)
    home.hold()
    try await save(.receipts, to: library)
    #expect(home.rows[1].detail == .count(2))
    #expect(home.viewRows[1].count == 2)

    home.release()
    #expect(home.rows[1].detail == .count(3))
    #expect(home.viewRows[1].count == 3)
}

@Test func releasePulsesOnlyTheCollectionsWhoseCountWentUp() async throws {
    let library = FakeLibrary(scans: scans(.receipts, 2) + scans(.wallet, 1))
    let home = model(library)
    #expect(home.rows.map(\.pulse) == [0, 0, 0, 0, 0])

    home.hold()
    try await save(.receipts, to: library)
    #expect(home.rows.map(\.pulse) == [0, 0, 0, 0, 0])
    home.release()
    #expect(home.rows.map(\.pulse) == [0, 1, 0, 0, 0])

    // A second save elsewhere pulses that row and leaves Receipts' trigger where it was.
    home.hold()
    try await save(.wallet, to: library)
    home.release()
    #expect(home.rows.map(\.pulse) == [1, 1, 0, 0, 0])
}

@Test func theFirstSaveCatchesUpFromTheFirstLaunchRowsAndPulses() async throws {
    let library = FakeLibrary()
    let home = model(library)
    home.hold()
    try await save(.notes, to: library)
    #expect(home.isEmpty)

    home.release()
    #expect(!home.isEmpty)
    #expect(home.rows[2].detail == .count(1))
    #expect(home.rows.map(\.pulse) == [0, 0, 1, 0, 0])
}

@Test func aReleaseWithNothingSavedOrNoHoldPulsesNothing() async throws {
    let library = FakeLibrary(scans: scans(.receipts, 1))
    let home = model(library)
    home.hold()
    home.release()
    // A change while Home isn't held (seeding at launch, say) shows at once and doesn't pulse.
    try await save(.receipts, to: library)
    home.release()
    #expect(home.rows[1].detail == .count(2))
    #expect(home.rows.map(\.pulse) == [0, 0, 0, 0, 0])
}

@Test func aSecondHoldKeepsTheFirstSnapshot() async throws {
    let library = FakeLibrary(scans: scans(.receipts, 1))
    let home = model(library)
    home.hold()
    try await save(.receipts, to: library)
    home.hold()
    #expect(home.rows[1].detail == .count(1))

    home.release()
    #expect(home.rows[1].detail == .count(2))
    #expect(home.rows.map(\.pulse) == [0, 1, 0, 0, 0])
}
