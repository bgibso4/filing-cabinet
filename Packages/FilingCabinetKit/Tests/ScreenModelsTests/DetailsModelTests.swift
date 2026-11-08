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
private let jul19 = CalendarDay(year: 2026, month: 7, day: 19)
private let oct1 = CalendarDay(year: 2026, month: 10, day: 1)

private func summary(
    _ title: String,
    _ collection: BuiltInCollection,
    scanned: CalendarDay,
    pages: Int = 1,
    override: ExpiryOverride? = nil
) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: scanned.date(in: utc).addingTimeInterval(12 * 3600),
        expiryOverride: override,
        pageCount: pages)
}

/// One scan open in Details on Oct 12, 2026, with a clock the test can move.
@MainActor
private struct DetailsHarness {
    let now = MovableNow(noon)
    let analytics = RecordingAnalytics()
    let library: FakeLibrary
    let today: Today
    let model: DetailsModel

    init(_ scan: ScanSummary) {
        let clock = AppClock.fixed(noon, calendar: utc)
        library = FakeLibrary(scans: [scan], clock: clock)
        let now = now
        let movingClock = AppClock(now: { now.now }, calendar: utc, locale: Locale(identifier: "en_US"))
        today = Today(clock: movingClock)
        model = DetailsModel(id: scan.id, library: library, today: today, clock: movingClock, analytics: analytics)
    }

    var scan: ScanSummary? { library.scans.first }
}

private var receipt: ScanSummary { summary("Corner Market", .receipts, scanned: jul19) }
private var lease: ScanSummary { summary("Lease 2026", .documents, scanned: oct1, pages: 3) }

// MARK: - Reading

@Test func receiptReadsItsExpiryInOrange() {
    let details = DetailsHarness(receipt).model
    #expect(details.title == "Corner Market")
    #expect(details.collection == .receipts)
    #expect(details.collectionName == "Receipts")
    #expect(details.expiryValue == "Oct 16 · 5 days left")
    #expect(details.isExpirySoon)
    #expect(!details.isMissing)
}

@Test func leaseReadsKeptForever() {
    let details = DetailsHarness(lease).model
    #expect(details.expiryValue == "Kept forever")
    #expect(!details.isExpirySoon)
}

@Test func scannedLineHasYearAndPages() {
    #expect(DetailsHarness(lease).model.scannedLine == "Scanned Oct 1, 2026 · 3 pages")
    #expect(DetailsHarness(receipt).model.scannedLine == "Scanned Jul 19, 2026 · 1 page")
}

@Test func optionsShowTheLibrarysLifespans() throws {
    let harness = DetailsHarness(receipt)
    try harness.library.setLifespan(.year, for: .receipts)
    #expect(
        harness.model.collectionOptions.map(\.lifespan) == [
            "Kept forever", "1 year", "Kept forever", "Kept forever", "1 week",
        ])
    #expect(harness.model.expiryOptions.first?.detail == "Jul 18, 2027")
    #expect(harness.model.expiryValue == "Jul 18, 2027 · 9 months left")
}

// MARK: - Title

@Test func renameTrimsAndBlankKeepsTitle() {
    let harness = DetailsHarness(receipt)
    harness.model.rename("  Corner Market groceries \n")
    #expect(harness.model.title == "Corner Market groceries")
    harness.model.rename("   ")
    #expect(harness.model.title == "Corner Market groceries")
    #expect(harness.scan?.title == "Corner Market groceries")
}

@Test func renamingEndsOnRenameEvenWhenBlank() {
    let harness = DetailsHarness(receipt)
    #expect(!harness.model.isRenaming)
    harness.model.startRenaming()
    #expect(harness.model.isRenaming)
    harness.model.rename("   ")
    #expect(!harness.model.isRenaming)
    #expect(harness.model.title == "Corner Market")
    harness.model.startRenaming()
    harness.model.rename("Groceries")
    #expect(!harness.model.isRenaming)
    #expect(harness.model.title == "Groceries")
}

// MARK: - Collection

@Test func moveToDocumentsFollowsAndCanUndo() {
    let harness = DetailsHarness(receipt)
    harness.model.choose(.documents)
    #expect(harness.model.collection == .documents)
    #expect(harness.model.movedNote == .follows("Documents"))
    #expect(harness.model.movedNote?.text == "Expiry now follows Documents.")
    #expect(harness.model.expiryValue == "Kept forever")

    harness.model.undoMove()
    #expect(harness.model.collection == .receipts)
    #expect(harness.model.movedNote == nil)
    #expect(harness.model.expiryValue == "Oct 16 · 5 days left")
}

@Test func moveWithCustomExpiryKeepsIt() {
    let harness = DetailsHarness(summary("Corner Market", .receipts, scanned: jul19, override: .lifespan(.year)))
    harness.model.choose(.notes)
    #expect(harness.model.collection == .notes)
    #expect(harness.model.movedNote == .keepsOwn)
    #expect(harness.model.movedNote?.text == "Keeps its own expiry.")
    #expect(harness.model.expiryValue == "Jul 18, 2027 · 9 months left")
}

@Test func theNextEditEndsUndo() {
    let harness = DetailsHarness(receipt)
    harness.model.choose(.documents)
    harness.model.rename("Groceries")
    #expect(harness.model.movedNote == nil)
    harness.model.undoMove()
    #expect(harness.model.collection == .documents)
}

@Test func moveThatWouldTrashAsksFirst() {
    let harness = DetailsHarness(receipt)
    harness.model.choose(.throwaways)
    #expect(harness.model.pendingTrashMove?.title == "Move to Throwaways?")
    #expect(
        harness.model.pendingTrashMove?.message
            == "Throwaways are kept 1 week from the scan date. This receipt is from Jul 19, so it goes to Trash now. "
            + "You can restore it for 30 days.")
    #expect(harness.model.collection == .receipts)
    #expect(harness.model.movedNote == nil)

    harness.model.cancelTrashMove()
    #expect(harness.model.pendingTrashMove == nil)
    #expect(harness.model.collection == .receipts)

    harness.model.choose(.throwaways)
    harness.model.confirmTrashMove()
    #expect(harness.model.pendingTrashMove == nil)
    #expect(harness.model.isMissing)
    let place = harness.scan?.place(lifespans: harness.library.lifespans, today: oct12, in: utc)
    #expect(place == .trash(daysLeft: 30, entered: oct12))
}

// MARK: - Expiry

@Test func detailsCloseWhenTheScanExpires() {
    // A throwaway scanned Oct 6 lives through Oct 12.
    let harness = DetailsHarness(
        summary("Coat check", .throwaways, scanned: CalendarDay(year: 2026, month: 10, day: 6)))
    #expect(!harness.model.isMissing)
    harness.now.set(noon.addingTimeInterval(86_400))
    harness.today.refresh()
    #expect(harness.model.isMissing)
}

@Test func passedExpiryCannotBeChosen() {
    let harness = DetailsHarness(lease)
    #expect(harness.model.expiryOptions.map(\.isPassed) == [false, true, false, false, false, false])
    harness.model.chooseExpiry(.lifespan(.week))
    #expect(harness.scan?.expiryOverride == nil)
    #expect(harness.model.expiryValue == "Kept forever")
    #expect(harness.analytics.events.isEmpty)

    harness.model.chooseExpiry(.lifespan(.month))
    #expect(harness.scan?.expiryOverride == .lifespan(.month))
    #expect(harness.model.expiryValue == "Oct 30 · 19 days left")
}

@Test func dateBeforeTodayIsRefused() {
    let harness = DetailsHarness(lease)
    harness.model.chooseExpiryDate(CalendarDay(year: 2026, month: 10, day: 11).date(in: utc))
    #expect(harness.scan?.expiryOverride == nil)
    harness.model.chooseExpiryDate(oct12.date(in: utc))
    #expect(harness.scan?.expiryOverride == .lastDay(oct12))
    #expect(harness.model.expiryValue == "Oct 12 · 1 day left")
    #expect(harness.model.isExpirySoon)
}

@Test func customDatesStartTodayInTheClocksCalendar() {
    let harness = DetailsHarness(lease)
    #expect(harness.model.earliestCustomDate == oct12.date(in: utc))
    #expect(harness.model.calendar == utc)
    #expect(harness.model.locale == Locale(identifier: "en_US"))
    harness.now.set(noon.addingTimeInterval(24 * 3600))
    harness.today.refresh()
    #expect(harness.model.earliestCustomDate == CalendarDay(year: 2026, month: 10, day: 13).date(in: utc))
}

// MARK: - Failures and analytics

@Test func failedEditShowsTheAlert() {
    let harness = DetailsHarness(receipt)
    harness.library.failNextEdit = .writeFailed
    harness.model.rename("Groceries")
    #expect(harness.model.editAlert?.title == "Couldn’t save this change")
    #expect(harness.model.editAlert?.message == "Something went wrong. Try again.")
    #expect(harness.model.title == "Corner Market")
    #expect(harness.analytics.events.isEmpty)
}

@Test func editAlertIsDismissed() {
    let harness = DetailsHarness(receipt)
    harness.library.failNextEdit = .writeFailed
    harness.model.rename("Groceries")
    #expect(harness.model.editAlert != nil)
    harness.model.dismissEditAlert()
    #expect(harness.model.editAlert == nil)
}

@Test func failedMoveKeepsNoUndo() {
    let harness = DetailsHarness(receipt)
    harness.library.failNextEdit = .writeFailed
    harness.model.choose(.documents)
    #expect(harness.model.editAlert != nil)
    #expect(harness.model.collection == .receipts)
    #expect(harness.model.movedNote == nil)
}

@Test func editsSendAnalytics() {
    let harness = DetailsHarness(receipt)
    harness.model.rename("Groceries")
    harness.model.rename("Groceries")
    harness.model.choose(.documents)
    harness.model.choose(.documents)
    harness.model.chooseExpiry(.lifespan(.year))
    #expect(
        harness.analytics.events == [
            .scanEdited(field: .title), .scanEdited(field: .collection), .scanEdited(field: .expiry),
        ])
}
