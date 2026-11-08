import Core
import Foundation
import Testing

@testable import ScreenModels

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
private let clock = AppClock.fixed(oct12.date(in: utc).addingTimeInterval(12 * 3600), calendar: utc)

private func options(
    _ collection: BuiltInCollection,
    scanned scanDay: CalendarDay,
    override: ExpiryOverride? = nil,
    lifespans: CollectionLifespans = .defaults
) -> [ExpiryOption] {
    ExpiryChoices(scanDay: scanDay, today: oct12, lifespans: lifespans, clock: clock)
        .options(collection: collection, override: override)
}

@Test func passedChoicesAreGreyed() {
    // A lease scanned Oct 1: a week ran out on Oct 7, a month runs to Oct 30.
    let lease = options(.documents, scanned: CalendarDay(year: 2026, month: 10, day: 1))
    #expect(lease.map(\.label) == ["Documents default", "1 week", "1 month", "3 months", "1 year", "Forever"])
    #expect(
        lease.map(\.detail) == ["Never expires", "Oct 7 · passed", "Oct 30", "Dec 29", "Sep 30, 2027", "Never expires"])
    #expect(lease.map(\.isPassed) == [false, true, false, false, false, false])
    #expect(lease.map(\.isSelected) == [true, false, false, false, false, false])
}

@Test func theLastDayItselfHasNotPassed() {
    let scanned = CalendarDay(year: 2026, month: 10, day: 6)
    let week = options(.documents, scanned: scanned)[1]
    #expect(week.detail == "Oct 12")
    #expect(!week.isPassed)
}

@Test func theDefaultFollowsTheLibrarysLifespans() {
    let monthlyReceipts = CollectionLifespans.defaults.setting(.month, for: .receipts)
    let receipt = options(.receipts, scanned: oct12, override: .lifespan(.year), lifespans: monthlyReceipts)
    #expect(receipt.first?.detail == "Nov 10")
    #expect(receipt.map(\.isSelected) == [false, false, false, false, true, false])
}
