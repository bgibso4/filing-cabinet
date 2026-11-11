import Core
import Foundation
import Library
import Observation
import Synchronization
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private let noon = CalendarDay(year: 2026, month: 10, day: 12).date(in: utc).addingTimeInterval(12 * 3600)

func scan(_ title: String, _ collection: BuiltInCollection, daysAgo: Int = 0) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: noon.addingTimeInterval(Double(-daysAgo) * 86_400),
        expiryOverride: nil,
        pageCount: 1)
}

private func model(_ kind: GridKind, _ summaries: [ScanSummary] = []) -> CollectionGridModel {
    let clock = AppClock.fixed(noon, calendar: utc)
    return CollectionGridModel(
        kind: kind,
        library: FakeLibrary(scans: summaries),
        today: Today(clock: clock),
        calendar: utc,
        analytics: RecordingAnalytics(),
        export: ExportFolder().export)
}

@Test func receiptsSubtitleAndTilesNewestFirst() {
    let grid = model(
        .collection(.receipts),
        [
            scan("Harbor Gas", .receipts, daysAgo: 5), scan("Corner Market", .receipts),
            scan("Bluebird Café", .receipts, daysAgo: 2), scan("Work ID", .wallet),
        ])
    #expect(grid.title == "Receipts")
    #expect(grid.subtitle == "3 scans · 3 months")
    #expect(!grid.isEmpty)
    #expect(grid.tiles.map(\.title) == ["Corner Market", "Bluebird Café", "Harbor Gas"])
    #expect(grid.tiles.allSatisfy { $0.dot == nil })
    #expect(grid.tiles.first?.timeLeft == "3 months left")
    #expect(grid.tiles.first?.accessibilityLabel == "Corner Market, Receipts, 3 months left")
    #expect(model(.collection(.wallet), [scan("Work ID", .wallet)]).subtitle == "1 scan · Forever")
}

@Test func emptyReceiptsCopy() {
    let grid = model(.collection(.receipts))
    #expect(grid.isEmpty)
    #expect(grid.tiles.isEmpty)
    #expect(grid.subtitle == "No scans · 3 months")
    #expect(grid.emptyTitle == "No receipts yet")
    #expect(grid.emptyBody == "Purchase receipts go here. Each one is kept 3 months, then moves to Trash.")
    #expect(model(.collection(.throwaways)).subtitle == "No scans · 1 week")
}

@Test func emptyNotesAndDocumentsCopy() {
    let notes = model(.collection(.notes))
    #expect(notes.emptyTitle == "No notes yet")
    #expect(notes.emptyBody == "Handwritten and class notes go here. They’re kept forever.")
    let documents = model(.collection(.documents))
    #expect(documents.emptyTitle == "No documents yet")
    #expect(documents.emptyBody == "Forms, letters and anything else go here. They’re kept forever.")
}

@Test func recentShowsDotsAndLastThirtyDays() {
    let grid = model(
        .recent,
        [
            scan("Today", .receipts), scan("Day 29", .notes, daysAgo: 29), scan("Day 30", .notes, daysAgo: 30),
        ])
    #expect(grid.title == "Recent")
    #expect(grid.subtitle == "Last 30 days")
    #expect(grid.tiles.map(\.title) == ["Today", "Day 29"])
    #expect(grid.tiles.map(\.dot) == [.receipts, .notes])
    #expect(grid.emptyTitle == "Nothing recent")
    #expect(model(.recent).subtitle == "Last 30 days")
}

@Test func allCountsEverythingVisible() {
    let scans = (0..<91).map { scan("Scan \($0)", .notes, daysAgo: $0) }
    let grid = model(.all, scans)
    #expect(grid.title == "All Scans")
    #expect(grid.subtitle == "91 scans")
    #expect(grid.tiles.count == 91)
    #expect(grid.tiles.first?.dot == .notes)
    #expect(model(.all, [scan("One", .wallet)]).subtitle == "1 scan")
    #expect(model(.all).subtitle == "No scans")
    #expect(model(.all).emptyTitle == "No scans yet")
}

@Test func walletIsCardShapedWithTwoColumnsThenOne() {
    let wallet = model(.collection(.wallet))
    #expect(wallet.tileShape == .card)
    #expect(wallet.columns(largeText: false) == 2)
    #expect(wallet.columns(largeText: true) == 1)
    for kind in [GridKind.collection(.receipts), .recent, .all] {
        let grid = model(kind)
        #expect(grid.tileShape == .page)
        #expect(grid.columns(largeText: false) == 3)
        #expect(grid.columns(largeText: true) == 2)
    }
}

@Test func expiredScansAreHidden() {
    let scans = [
        scan("Kept", .throwaways, daysAgo: 6), scan("Gone", .throwaways, daysAgo: 7),
        scan("Old receipt", .receipts, daysAgo: 90),
    ]
    let throwaways = model(.collection(.throwaways), scans)
    #expect(throwaways.tiles.map(\.title) == ["Kept"])
    #expect(throwaways.subtitle == "1 scan · 1 week")
    #expect(model(.collection(.receipts), scans).isEmpty)
    #expect(model(.all, scans).subtitle == "1 scan")
}

@Test func soonTileIsFlagged() {
    let throwaways = model(
        .collection(.throwaways),
        [scan("Last day", .throwaways, daysAgo: 6), scan("Two days", .throwaways, daysAgo: 5)]
    ).tiles
    #expect(throwaways.map(\.timeLeft) == ["2 days left", "1 day left"])
    #expect(throwaways.map(\.isSoon) == [false, true])

    let receipts = model(
        .collection(.receipts),
        [scan("Seven", .receipts, daysAgo: 83), scan("Eight", .receipts, daysAgo: 82)]
    ).tiles
    #expect(receipts.map(\.timeLeft) == ["8 days left", "7 days left"])
    #expect(receipts.map(\.isSoon) == [false, true])

    #expect(model(.collection(.wallet), [scan("Forever", .wallet)]).tiles.map(\.isSoon) == [false])
}

@Test func onlyMixedGridsShowWideScansWhole() {
    #expect(model(.recent).showsWideScansWhole)
    #expect(model(.all).showsWideScansWhole)
    for collection in BuiltInCollection.allCases {
        #expect(!model(.collection(collection)).showsWideScansWhole)
    }
}

@Test func gridFollowsANewDay() {
    let now = MovableNow(noon)
    let clock = AppClock(now: { now.now }, calendar: utc, locale: Locale(identifier: "en_US"))
    let today = Today(clock: clock)
    let library = FakeLibrary(scans: [scan("Coat check", .throwaways, daysAgo: 5)])
    let grid = CollectionGridModel(
        kind: .collection(.throwaways),
        library: library,
        today: today,
        calendar: utc,
        analytics: RecordingAnalytics(),
        export: ExportFolder().export)
    #expect(grid.tiles.map(\.timeLeft) == ["2 days left"])

    now.set(noon.addingTimeInterval(86_400))
    today.refresh()
    #expect(grid.tiles.map(\.timeLeft) == ["1 day left"])
    now.set(noon.addingTimeInterval(2 * 86_400))
    today.refresh()
    #expect(grid.isEmpty)
}

@Test func gridFollowsTheLibraryEvenWhenTheShelfIsAlreadyBuilt() async throws {
    let library = FakeLibrary()
    let clock = AppClock.fixed(noon, calendar: utc)
    let grid = CollectionGridModel(
        kind: .all,
        library: library,
        today: Today(clock: clock),
        calendar: utc,
        analytics: RecordingAnalytics(),
        export: ExportFolder().export)
    #expect(grid.isEmpty)

    let changed = Mutex(false)
    withObservationTracking {
        _ = grid.isEmpty
        _ = grid.subtitle
    } onChange: {
        changed.withLock { $0 = true }
    }
    try await library.save(
        ScanDraft(
            id: ScanID(),
            title: "New",
            collection: .notes,
            scannedAt: noon,
            expiryOverride: nil,
            pages: [],
            searchText: ""
        ))
    #expect(changed.withLock { $0 })
    #expect(grid.subtitle == "1 scan")
}
// MARK: - Select (#68)

/// A grid with its library and analytics, for select mode.
@MainActor
struct GridHarness {
    let analytics = RecordingAnalytics()
    let library: FakeLibrary
    let grid: CollectionGridModel
    private let clock = AppClock.fixed(noon, calendar: utc)

    private let export: ScanExport

    init(_ kind: GridKind, _ summaries: [ScanSummary], export: ScanExport = ExportFolder().export) {
        library = FakeLibrary(scans: summaries, clock: clock)
        self.export = export
        grid = CollectionGridModel(
            kind: kind,
            library: library,
            today: Today(clock: clock),
            calendar: utc,
            analytics: analytics,
            export: export)
    }

    /// The same grid opened again: a new model over the same library, as the screen builds when it is pushed.
    func reopened() -> CollectionGridModel {
        CollectionGridModel(
            kind: grid.kind,
            library: library,
            today: Today(clock: clock),
            calendar: utc,
            analytics: analytics,
            export: export)
    }
}

private var threeReceipts: [ScanSummary] {
    [
        scan("Corner Market", .receipts), scan("Bluebird Café", .receipts, daysAgo: 1),
        scan("Harbor Gas", .receipts, daysAgo: 2),
    ]
}

@Test func selectingReadsTheCountAndMoveTitle() {
    let grid = GridHarness(.collection(.receipts), threeReceipts).grid
    grid.toggleSelecting()
    #expect(grid.isSelecting)
    #expect(grid.subtitle == "0 selected")
    #expect(!grid.canAct)
    #expect(grid.moveTitle == "Move to Trash")
    grid.toggle(grid.tiles[0].id)
    #expect(grid.canAct)
    #expect(grid.subtitle == "1 selected")
    #expect(grid.moveTitle == "Move to Trash")
    #expect(grid.moveMessage == "This receipt moves to Trash. You can restore it for 30 days.")
    grid.toggle(grid.tiles[1].id)
    #expect(grid.moveTitle == "Move 2 to Trash")
    #expect(grid.moveMessage == "These 2 receipts move to Trash. You can restore them for 30 days.")
    grid.toggleSelecting()
    #expect(!grid.isSelecting)
    #expect(grid.selected.isEmpty)
    #expect(grid.subtitle == "3 scans · 3 months")
}

/// Recent and All Scans mix collections: a selection from more than one is called scans.
@Test func aMixedSelectionIsCalledScans() {
    let grid = GridHarness(
        .all, [scan("Work ID", .wallet), scan("Corner Market", .receipts, daysAgo: 1)]
    ).grid
    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    #expect(grid.moveMessage == "This card moves to Trash. You can restore it for 30 days.")
    grid.toggle(grid.tiles[1].id)
    #expect(grid.moveMessage == "These 2 scans move to Trash. You can restore them for 30 days.")
}

@Test func movingTheSelectionToTrashEndsSelectMode() {
    let harness = GridHarness(.collection(.receipts), threeReceipts)
    let grid = harness.grid
    let kept = grid.tiles[2].id
    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    grid.toggle(grid.tiles[1].id)
    #expect(grid.moveSelectedToTrash() == "Moved 2 scans to Trash")
    #expect(grid.tiles.map(\.id) == [kept])
    #expect(!grid.isSelecting)
    #expect(harness.library.scans.count { $0.trashedDay != nil } == 2)
    #expect(
        harness.analytics.events == [
            .scanMovedToTrash(collection: .receipts), .scanMovedToTrash(collection: .receipts),
        ])
}

@Test func movingOneAnnouncesMovedToTrash() {
    let grid = GridHarness(.collection(.receipts), threeReceipts).grid
    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    #expect(grid.moveSelectedToTrash() == "Moved to Trash")
}

@Test func movingTheLastScanEmptiesTheGrid() {
    let grid = GridHarness(.collection(.wallet), [scan("Work ID", .wallet)]).grid
    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    #expect(grid.moveSelectedToTrash() != nil)
    #expect(grid.isEmpty)
    #expect(!grid.isSelecting)
}

@Test func movingNothingDoesNothing() {
    let harness = GridHarness(.collection(.receipts), threeReceipts)
    harness.grid.toggleSelecting()
    #expect(harness.grid.moveSelectedToTrash() == nil)
    #expect(harness.grid.isSelecting)
    #expect(harness.analytics.events.isEmpty)
}

@Test func aFailedMoveAlertsAndChangesNothing() {
    let harness = GridHarness(.collection(.receipts), threeReceipts)
    let grid = harness.grid
    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    harness.library.failNextEdit = .writeFailed
    #expect(grid.moveSelectedToTrash() == nil)
    #expect(grid.editAlert == EditAlert())
    #expect(grid.tiles.count == 3)
    #expect(grid.isSelecting)
    #expect(grid.selected.count == 1)
    #expect(harness.analytics.events.isEmpty)
    grid.dismissEditAlert()
    #expect(grid.editAlert == nil)
}

/// A scan that leaves the grid (moved from another screen, or expired overnight) leaves the selection.
@Test func theSelectionDropsScansThatLeaveTheGrid() throws {
    let harness = GridHarness(.collection(.receipts), threeReceipts)
    let grid = harness.grid
    grid.toggleSelecting()
    let leaving = grid.tiles[0].id
    grid.toggle(leaving)
    grid.toggle(grid.tiles[1].id)
    try harness.library.moveToTrash([leaving])
    #expect(grid.selected.count == 1)
    #expect(grid.moveTitle == "Move to Trash")
}
