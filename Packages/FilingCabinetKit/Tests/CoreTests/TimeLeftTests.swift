import Foundation
import Testing

@testable import Core

@Test func throwawayShowsSevenDaysOnItsScanDayAndOneOnItsLast() {
    let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
    let last = Expiry.lastDay(scanDay: oct12, collectionLifespan: .week, override: nil, in: cal)
    #expect(last == CalendarDay(year: 2026, month: 10, day: 18))
    #expect(TimeLeft.on(oct12, lastDay: last, in: cal) == .days(7))
    #expect(TimeLeft.on(CalendarDay(year: 2026, month: 10, day: 18), lastDay: last, in: cal) == .days(1))
    #expect(TimeLeft.on(CalendarDay(year: 2026, month: 10, day: 19), lastDay: last, in: cal) == .expired)
}

@Test func daysLeftAcrossDaylightSavingChange() {
    // US daylight saving time ends on Nov 1 2026.
    let last = CalendarDay(year: 2026, month: 11, day: 3)
    #expect(TimeLeft.on(CalendarDay(year: 2026, month: 10, day: 30), lastDay: last, in: cal) == .days(5))
}

@Test func orangeRule() {
    #expect(TimeLeft.isSoon(daysLeft: 7, spanDays: 90))
    #expect(!TimeLeft.isSoon(daysLeft: 8, spanDays: 90))
    #expect(!TimeLeft.isSoon(daysLeft: 2, spanDays: 7))
    #expect(TimeLeft.isSoon(daysLeft: 1, spanDays: 7))
}

@Test func daysLeftAcrossSpringForward() {
    let last = CalendarDay(year: 2027, month: 3, day: 15)
    #expect(TimeLeft.on(CalendarDay(year: 2027, month: 3, day: 13), lastDay: last, in: cal) == .days(3))
    #expect(TimeLeft.on(CalendarDay(year: 2027, month: 3, day: 14), lastDay: last, in: cal) == .days(2))
}
