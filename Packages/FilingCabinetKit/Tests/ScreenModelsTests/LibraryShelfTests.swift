import Core
import Foundation
import Library
import Testing

@testable import ScreenModels

private var newYork: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
    return calendar
}

private func at(_ day: CalendarDay) -> Date { day.date(in: newYork).addingTimeInterval(12 * 3600) }

private let today = CalendarDay(year: 2026, month: 11, day: 2)

private func scan(
    _ collection: BuiltInCollection,
    daysAgo: Int,
    override: ExpiryOverride? = nil
) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: "Scan",
        collection: collection,
        scannedAt: at(today.adding(days: -daysAgo, in: newYork)),
        expiryOverride: override,
        pageCount: 1)
}

private func shelf(_ scans: [ScanSummary]) -> LibraryShelf {
    LibraryShelf(scans: scans, today: today, calendar: newYork)
}

@Test func shelfHidesExpiredAndCountsPerCollection() {
    let live = scan(.throwaways, daysAgo: 6)  // day 7 of 7: last day
    let expired = scan(.throwaways, daysAgo: 7)
    let receipt = scan(.receipts, daysAgo: 30)
    let wallet = scan(.wallet, daysAgo: 400)
    let subject = shelf([expired, live, receipt, wallet])
    #expect(Set(subject.visible.map(\.id)) == [live.id, receipt.id, wallet.id])
    #expect(subject.count(in: .throwaways) == 1)
    #expect(subject.count(in: .receipts) == 1)
    #expect(subject.count(in: .notes) == 0)
    #expect(subject.in(.throwaways).map(\.id) == [live.id])
}

@Test func visibleIsNewestFirst() {
    let old = scan(.wallet, daysAgo: 5)
    let new = scan(.notes, daysAgo: 1)
    let mid = scan(.wallet, daysAgo: 3)
    #expect(shelf([old, new, mid]).visible.map(\.id) == [new.id, mid.id, old.id])
}

@Test func recentIsThirtyDaysIncludingToday() {
    let day29 = scan(.wallet, daysAgo: 29)
    let day30 = scan(.wallet, daysAgo: 30)
    let todays = scan(.wallet, daysAgo: 0)
    let recent = shelf([day30, day29, todays]).recent
    #expect(recent.map(\.id) == [todays.id, day29.id])
}

@Test func soonUsesTheScansOwnSpan() {
    // Receipt (90 days): soon in its last 7 days.
    let receiptSoon = scan(.receipts, daysAgo: 83)  // day 84 -> 7 left
    let receiptLater = scan(.receipts, daysAgo: 82)  // 8 left
    // Throwaway (7-day span): soon only on the last day.
    let throwawayLast = scan(.throwaways, daysAgo: 6)
    let throwawayEarlier = scan(.throwaways, daysAgo: 5)
    // A wallet scan given a 7-day override uses that span too.
    let overridden = scan(.wallet, daysAgo: 5, override: .lifespan(.week))
    let forever = scan(.wallet, daysAgo: 500)
    let subject = shelf([receiptSoon, receiptLater, throwawayLast, throwawayEarlier, overridden, forever])
    #expect(subject.isSoon(receiptSoon))
    #expect(!subject.isSoon(receiptLater))
    #expect(subject.isSoon(throwawayLast))
    #expect(!subject.isSoon(throwawayEarlier))
    #expect(!subject.isSoon(overridden))
    #expect(!subject.isSoon(forever))
    #expect(subject.timeLeft(receiptSoon) == .days(7))
    #expect(subject.timeLeft(forever) == .forever)
}

@Test func everyGridHasEmptyCopy() {
    let grids: [GridKind] = BuiltInCollection.allCases.map { .collection($0) } + [.recent, .all]
    for grid in grids {
        #expect(!CollectionText.emptyTitle(grid).isEmpty)
        #expect(!CollectionText.emptyBody(grid).isEmpty)
    }
    #expect(CollectionText.emptyTitle(.collection(.notes)) == "No notes yet")
    #expect(
        CollectionText.emptyBody(.collection(.receipts))
            == "Purchase receipts go here. Each one is kept 3 months, then moves to Trash.")
    #expect(CollectionText.emptyBody(.recent) == "Scans from the last 30 days show up here.")
    #expect(GridKind.collection(.wallet).preselection == .wallet)
    #expect(GridKind.recent.preselection == nil)
}

@Test func lifespanCopy() {
    #expect(CollectionText.lifespanShort(.forever) == "Kept forever")
    #expect(CollectionText.lifespanShort(.week) == "1 week")
    #expect(CollectionText.lifespanShort(.threeMonths) == "3 months")
    #expect(CollectionText.lifespanShort(.year) == "1 year")
    #expect(CollectionText.kept(.week) == "Kept 1 week")
    #expect(CollectionText.kept(.forever) == "Kept forever")
}
