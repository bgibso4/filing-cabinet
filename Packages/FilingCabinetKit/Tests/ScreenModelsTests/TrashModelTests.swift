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
    #expect(TrashHarness(three).model.subtitle == "3 scans · 30 days")
    #expect(TrashHarness([coatCheck]).model.subtitle == "1 scan · 30 days")
}

/// B15: an empty Trash still has a subtext under its large title, as Passwords' "0 Items".
@Test func emptyTrashSaysNoScans() {
    let empty = TrashHarness([]).model
    #expect(empty.subtitle == "No scans")
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

/// Each confirmation comes up from the button that asked (Ben, 2026-11-08): Empty Trash's from Empty Trash, a
/// selection's from Delete N, a long-pressed tile's from that tile, and only from there.
@Test func eachConfirmationHasOnePlaceItComesUpFrom() {
    let model = TrashHarness(three).model
    let first = model.tiles[0].id
    let second = model.tiles[1].id

    model.confirmEmpty()
    #expect(model.emptyConfirmation == model.confirmation)
    #expect(model.selectionConfirmation == nil)
    #expect(model.tileConfirmation(first) == nil)

    model.confirmDelete([first])
    #expect(model.emptyConfirmation == nil)
    #expect(model.selectionConfirmation == nil)
    #expect(model.tileConfirmation(first) == model.confirmation)
    #expect(model.tileConfirmation(second) == nil)

    model.cancelConfirmation()
    model.toggleSelecting()
    model.toggle(first)
    model.confirmDelete([first])
    #expect(model.emptyConfirmation == nil)
    #expect(model.selectionConfirmation == model.confirmation)
    #expect(model.tileConfirmation(first) == nil)

    model.cancelConfirmation()
    #expect(model.emptyConfirmation == nil)
    #expect(model.selectionConfirmation == nil)
    #expect(model.tileConfirmation(first) == nil)
}

/// In select mode, VoiceOver's Delete now on one tile asks from that tile, not from Delete N, which deletes the ticked
/// scans and may be off.
@Test func selectModeDeleteOfOneTileAsksFromTheTile() {
    let model = TrashHarness(three).model
    let first = model.tiles[0].id
    let second = model.tiles[1].id
    model.toggleSelecting()

    model.confirmDelete([first])  // nothing ticked: Delete N is off
    #expect(model.selectionConfirmation == nil)
    #expect(model.tileConfirmation(first) == model.confirmation)

    model.cancelConfirmation()
    model.toggle(first)
    model.confirmDelete([second])  // not the ticked one
    #expect(model.selectionConfirmation == nil)
    #expect(model.tileConfirmation(second) == model.confirmation)
    #expect(model.tileConfirmation(first) == nil)
}

/// Select or Cancel drops a pending question, so a long-press Delete now whose popover never showed can't come up
/// from select mode's controls.
@Test func switchingModesDropsAPendingQuestion() {
    let model = TrashHarness(three).model
    model.confirmDelete([model.tiles[0].id])
    model.toggleSelecting()
    #expect(model.confirmation == nil)
    model.confirmEmpty()
    model.toggleSelecting()
    #expect(model.confirmation == nil)
}

/// A pending delete counts as nothing once any of its scans has left Trash, so it can't come up later unasked.
@Test func aPendingDeleteIsNothingOnceItsScansLeaveTrash() {
    let model = TrashHarness(three).model
    let first = model.tiles[0].id
    let second = model.tiles[1].id
    model.confirmDelete([first, second])
    model.restore([first])
    #expect(model.confirmation == nil)
    #expect(model.tileConfirmation(second) == nil)
    model.toggleSelecting()
    #expect(model.selectionConfirmation == nil)
}

/// A pending Empty Trash counts as nothing once Trash is empty.
@Test func aPendingEmptyIsNothingOnceTrashIsEmpty() {
    let model = TrashHarness(three).model
    model.confirmEmpty()
    model.restore(model.tiles.map(\.id))
    #expect(model.isEmpty)
    #expect(model.confirmation == nil)
    #expect(model.emptyConfirmation == nil)
}

@Test func confirmedDeleteRemovesOnlyThoseScans() async throws {
    let harness = TrashHarness(three)
    let model = harness.model
    let ids = [model.tiles[0].id, model.tiles[1].id]
    model.confirmDelete(ids)
    #expect(harness.library.scans.count == 3)  // nothing happens until confirmed
    let announcement = try await model.performConfirmation(#require(model.confirmation))
    #expect(announcement == "Deleted 2 scans")
    #expect(model.confirmation == nil)
    #expect(model.tiles.map(\.title) == ["Coat check"])
    #expect(harness.analytics.events == [.scansDeleted(count: 2)])
}

/// The dialog clears the confirmation as it goes, which may be before its button's action runs: the action still
/// performs what was confirmed.
@Test func aConfirmationClearedByItsDialogStillPerforms() async throws {
    let harness = TrashHarness(three)
    harness.model.confirmEmpty()
    let confirmation = try #require(harness.model.confirmation)
    harness.model.cancelConfirmation()
    #expect(await harness.model.performConfirmation(confirmation) == "Deleted 3 scans")
    #expect(harness.library.scans.isEmpty)
}

@Test func deletingOneAnnouncesDeleted() async throws {
    let model = TrashHarness(three).model
    model.confirmDelete([model.tiles[0].id])
    #expect(try await model.performConfirmation(#require(model.confirmation)) == "Deleted")
}

@Test func emptyTrashDeletesAll() async throws {
    let harness = TrashHarness(three)
    harness.model.confirmEmpty()
    #expect(try await harness.model.performConfirmation(#require(harness.model.confirmation)) == "Deleted 3 scans")
    #expect(harness.model.isEmpty)
    #expect(harness.library.scans.isEmpty)
    #expect(harness.analytics.events == [.trashEmptied(count: 3)])
}

@Test func aFailedDeleteAlertsAndKeepsTheScans() async throws {
    let harness = TrashHarness(three)
    harness.library.failNextEdit = .writeFailed
    harness.model.confirmEmpty()
    #expect(try await harness.model.performConfirmation(#require(harness.model.confirmation)) == nil)
    #expect(harness.model.editAlert == EditAlert())
    #expect(harness.model.confirmation == nil)
    #expect(harness.model.tiles.count == 3)
    #expect(harness.analytics.events.isEmpty)
}

@Test func analyticsCounts() async throws {
    let harness = TrashHarness(three)
    let model = harness.model
    _ = model.restore([model.tiles[0].id])
    model.confirmDelete([model.tiles[0].id, model.tiles[1].id])
    _ = try await model.performConfirmation(#require(model.confirmation))
    #expect(harness.analytics.events == [.scansRestored(count: 1), .scansDeleted(count: 2)])
    #expect(harness.analytics.events.allSatisfy { Set($0.payload.keys) == [.count] })
}

/// E8: the notice above the tiles says how long scans stay; an empty Trash has none (its empty state says it).
@Test func theNoticeSaysHowLongScansStayAndGoesWhenEmpty() {
    #expect(
        TrashHarness(three).model.notice == "Scans stay in Trash for 30 days, then they’re permanently deleted.")
    #expect(TrashHarness([]).model.notice == nil)
}

@Test func trashTilesKeepTheirHeart() {
    var hearted = coatCheck
    hearted.favoriteOrder = 0
    let model = TrashHarness([hearted, pharmacy]).model
    #expect(model.tiles.filter(\.isFavorite).map(\.title) == ["Coat check"])
    let tile = model.tiles.first { $0.title == "Coat check" }
    #expect(tile?.isFavorite == true)
    #expect(tile?.accessibilityLabel == "Coat check, Throwaways, 28 days left, favorite")
    #expect(
        model.tiles.first { $0.title == "City Pharmacy" }?.accessibilityLabel
            == "City Pharmacy, Receipts, 1 day left")
}
