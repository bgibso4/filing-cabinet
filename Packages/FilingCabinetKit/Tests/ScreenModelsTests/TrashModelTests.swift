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

/// A scan in Trash since `trashed`: it has `30 - (days since)` days left on Oct 12.
private func trashed(
    _ title: String, _ collection: BuiltInCollection = .receipts, since trashed: CalendarDay
) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: noon.addingTimeInterval(-90 * 86_400),
        expiryOverride: nil,
        pageCount: 1,
        trashedDay: trashed)
}

private func daysAgo(_ days: Int) -> CalendarDay { oct12.adding(days: -days, in: utc) }

/// Trash on Oct 12, 2026, with a clock the test can move.
@MainActor
private struct TrashHarness {
    let now = MovableNow(noon)
    let analytics = RecordingAnalytics()
    let library: FakeLibrary
    let today: Today
    let model: TrashModel

    init(_ scans: [ScanSummary]) {
        library = FakeLibrary(scans: scans, clock: AppClock.fixed(noon, calendar: utc))
        let now = now
        let clock = AppClock(now: { now.now }, calendar: utc, locale: Locale(identifier: "en_US"))
        today = Today(clock: clock)
        model = TrashModel(library: library, today: today, calendar: utc, analytics: analytics)
    }
}

private var coatCheck: ScanSummary { trashed("Coat check", .throwaways, since: daysAgo(2)) }  // 28 left
private var pharmacy: ScanSummary { trashed("City Pharmacy", .receipts, since: daysAgo(29)) }  // 1 left
private var lease: ScanSummary { trashed("Lease 2026", .documents, since: daysAgo(25)) }  // 5 left

private var three: [ScanSummary] { [coatCheck, pharmacy, lease] }

// MARK: - Reading

@Test func tilesAreSoonestFirstWithDaysLeft() {
    let model = TrashHarness(three).model
    #expect(model.tiles.map(\.title) == ["City Pharmacy", "Lease 2026", "Coat check"])
    #expect(model.tiles.map(\.daysLeftText) == ["1 day left", "5 days left", "28 days left"])
    #expect(model.tiles.map(\.isSoon) == [true, true, false])
    #expect(model.tiles.map(\.collection) == [.receipts, .documents, .throwaways])
}

/// Requirements 06 · Accessibility: a tile reads as one line.
@Test func aTileReadsTitleCollectionAndDaysLeft() {
    let model = TrashHarness([coatCheck]).model
    #expect(model.tiles[0].accessibilityLabel == "Coat check, Throwaways, 28 days left")
}

@Test func subtitleCountsScans() {
    #expect(TrashHarness(three).model.subtitle == "3 scans · each is deleted after 30 days here")
    #expect(TrashHarness([coatCheck]).model.subtitle == "1 scan · each is deleted after 30 days here")
    let empty = TrashHarness([]).model
    #expect(empty.subtitle == nil)
    #expect(empty.isEmpty)
}

@Test func libraryScansNeverShowInTrash() {
    let inLibrary = ScanSummary(
        id: ScanID(), title: "Keeper", collection: .documents, scannedAt: noon, expiryOverride: nil, pageCount: 1)
    let model = TrashHarness([inLibrary, coatCheck]).model
    #expect(model.tiles.map(\.title) == ["Coat check"])
}

@Test func restoreLineNamesTheCollection() {
    let model = TrashHarness([coatCheck]).model
    #expect(model.restoreLine(for: model.tiles[0].id) == "To Throwaways, kept forever")
}

// MARK: - Select

@Test func selectingTwoReadsDelete2AndRestore2() {
    let model = TrashHarness(three).model
    model.toggleSelecting()
    #expect(model.isSelecting)
    #expect(model.subtitle == "0 selected")
    model.toggle(model.tiles[0].id)
    #expect(model.deleteTitle == "Delete")
    #expect(model.restoreTitle == "Restore")
    model.toggle(model.tiles[1].id)
    #expect(model.subtitle == "2 selected")
    #expect(model.deleteTitle == "Delete 2")
    #expect(model.restoreTitle == "Restore 2")
    model.toggle(model.tiles[1].id)
    #expect(model.selected == [model.tiles[0].id])
    model.toggleSelecting()
    #expect(!model.isSelecting)
    #expect(model.selected.isEmpty)
}

@Test func nothingSelectedDisablesActions() {
    let model = TrashHarness(three).model
    model.toggleSelecting()
    #expect(!model.canAct)
    model.toggle(model.tiles[0].id)
    #expect(model.canAct)
}

@Test func selectionDropsScansThatLeaveTrash() {
    let harness = TrashHarness(three)
    let model = harness.model
    model.toggleSelecting()
    let leaving = model.tiles[0].id  // Pharmacy, 1 day left
    let staying = model.tiles[2].id
    model.toggle(leaving)
    model.toggle(staying)
    #expect(model.deleteTitle == "Delete 2")

    harness.now.set(noon.addingTimeInterval(86_400))
    harness.today.refresh()

    #expect(model.selected == [staying])
    #expect(model.deleteTitle == "Delete")
    #expect(model.subtitle == "1 selected")
    #expect(!model.tiles.contains { $0.id == leaving })
}

// MARK: - Restore

@Test func restoreNeedsNoConfirmation() {
    let harness = TrashHarness(three)
    let model = harness.model
    let id = model.tiles[2].id
    #expect(model.restore([id]) == "Restored to Throwaways")
    #expect(model.confirmation == nil)
    #expect(harness.library.scans.first { $0.id == id }?.trashedDay == nil)
    #expect(model.tiles.count == 2)
    #expect(harness.analytics.events == [.scansRestored(count: 1)])
}

@Test func restoringSeveralAnnouncesTheCount() {
    let model = TrashHarness(three).model
    model.toggleSelecting()
    model.toggle(model.tiles[0].id)
    model.toggle(model.tiles[1].id)
    #expect(model.restore(Array(model.selected)) == "Restored 2 scans")
    #expect(!model.isSelecting)
    #expect(model.selected.isEmpty)
}

@Test func aFailedRestoreAlertsAndChangesNothing() {
    let harness = TrashHarness(three)
    harness.library.failNextEdit = .writeFailed
    #expect(harness.model.restore([harness.model.tiles[0].id]) == nil)
    #expect(harness.model.editAlert == EditAlert())
    #expect(harness.model.tiles.count == 3)
    #expect(harness.analytics.events.isEmpty)
    harness.model.dismissEditAlert()
    #expect(harness.model.editAlert == nil)
}

// MARK: - Delete and Empty Trash

@Test func confirmationCopyForOneSeveralAndEmpty() {
    let model = TrashHarness(three).model
    model.confirmDelete([model.tiles[2].id])
    #expect(model.confirmation?.title == "Delete permanently?")
    #expect(model.confirmation?.message == "Coat check will be deleted. This can’t be undone.")
    #expect(model.confirmation?.confirmTitle == "Delete")

    model.confirmDelete([model.tiles[0].id, model.tiles[1].id])
    #expect(model.confirmation?.title == "Delete 2 scans permanently?")
    #expect(model.confirmation?.message == "They’ll be deleted. This can’t be undone.")
    #expect(model.confirmation?.confirmTitle == "Delete")

    model.confirmEmpty()
    #expect(model.confirmation?.title == "Empty Trash?")
    #expect(model.confirmation?.message == "Deletes 3 scans permanently. This can’t be undone.")
    #expect(model.confirmation?.confirmTitle == "Empty Trash")

    model.cancelConfirmation()
    #expect(model.confirmation == nil)
}

@Test func confirmedDeleteRemovesOnlyThoseScans() async {
    let harness = TrashHarness(three)
    let model = harness.model
    let ids = [model.tiles[0].id, model.tiles[1].id]
    model.confirmDelete(ids)
    #expect(harness.library.scans.count == 3)  // nothing happens until confirmed
    let announcement = await model.performConfirmation()
    #expect(announcement == "Deleted 2 scans")
    #expect(model.confirmation == nil)
    #expect(model.tiles.map(\.title) == ["Coat check"])
    #expect(harness.analytics.events == [.scansDeleted(count: 2)])
}

@Test func deletingOneAnnouncesDeleted() async {
    let model = TrashHarness(three).model
    model.confirmDelete([model.tiles[0].id])
    #expect(await model.performConfirmation() == "Deleted")
}

@Test func emptyTrashDeletesAll() async {
    let harness = TrashHarness(three)
    harness.model.confirmEmpty()
    #expect(await harness.model.performConfirmation() == "Deleted 3 scans")
    #expect(harness.model.isEmpty)
    #expect(harness.library.scans.isEmpty)
    #expect(harness.analytics.events == [.trashEmptied(count: 3)])
}

@Test func aFailedDeleteAlertsAndKeepsTheScans() async {
    let harness = TrashHarness(three)
    harness.library.failNextEdit = .writeFailed
    harness.model.confirmEmpty()
    #expect(await harness.model.performConfirmation() == nil)
    #expect(harness.model.editAlert == EditAlert())
    #expect(harness.model.confirmation == nil)
    #expect(harness.model.tiles.count == 3)
    #expect(harness.analytics.events.isEmpty)
}

@Test func analyticsCounts() async {
    let harness = TrashHarness(three)
    let model = harness.model
    _ = model.restore([model.tiles[0].id])
    model.confirmDelete([model.tiles[0].id, model.tiles[1].id])
    _ = await model.performConfirmation()
    #expect(harness.analytics.events == [.scansRestored(count: 1), .scansDeleted(count: 2)])
    #expect(harness.analytics.events.allSatisfy { Set($0.payload.keys) == [.count] })
}
