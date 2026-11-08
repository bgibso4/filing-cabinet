import Core
import Foundation
import Testing

@testable import ScreenModels

private var newYork: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
    return calendar
}

private func clock(_ locale: String = "en_US") -> AppClock {
    .fixed(Date(timeIntervalSince1970: 1_791_000_000), calendar: newYork, locale: Locale(identifier: locale))
}

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)

@Test func reviewValueForAReceiptScannedOct12() {
    let value = ExpiryText.reviewValue(
        collection: .receipts, override: nil, scanDay: oct12, today: oct12, clock: clock())
    #expect(value == "3 months · until Jan 9, 2027")
}

@Test func reviewValueForForeverAndLifespanOverride() {
    #expect(
        ExpiryText.reviewValue(collection: .wallet, override: nil, scanDay: oct12, today: oct12, clock: clock())
            == "Kept forever")
    #expect(
        ExpiryText.reviewValue(
            collection: .receipts, override: .lifespan(.forever), scanDay: oct12, today: oct12, clock: clock())
            == "Kept forever")
    #expect(
        ExpiryText.reviewValue(
            collection: .wallet, override: .lifespan(.week), scanDay: oct12, today: oct12, clock: clock())
            == "1 week · until Oct 18")
}

@Test func yearHiddenWhenSameYear() {
    let jan9 = CalendarDay(year: 2027, month: 1, day: 9)
    #expect(ExpiryText.untilDate(jan9, today: CalendarDay(year: 2027, month: 1, day: 2), clock: clock()) == "Jan 9")
    #expect(ExpiryText.untilDate(jan9, today: oct12, clock: clock()) == "Jan 9, 2027")
}

@Test func customDateReadsUntil() {
    let mar3 = CalendarDay(year: 2027, month: 3, day: 3)
    let value = ExpiryText.reviewValue(
        collection: .receipts,
        override: .lastDay(mar3),
        scanDay: oct12,
        today: CalendarDay(year: 2027, month: 1, day: 1),
        clock: clock())
    #expect(value == "Until Mar 3")
}

@Test func dateTextIgnoresHostLocale() {
    let jan9 = CalendarDay(year: 2027, month: 1, day: 9)
    // Host locale is whatever the machine uses; the clock's locale decides.
    #expect(ExpiryText.untilDate(jan9, today: oct12, clock: clock("en_US")) == "Jan 9, 2027")
    let french = ExpiryText.untilDate(jan9, today: oct12, clock: clock("fr_FR"))
    #expect(french != "Jan 9, 2027")
    #expect(french.contains("janv"))
}
