import Foundation
import Testing

@testable import Core

@Test func storageValueRoundTrips() {
    let day = CalendarDay(year: 2027, month: 1, day: 9)
    #expect(day.storageValue == 20_270_109)
    #expect(CalendarDay(storageValue: 20_270_109) == day)
    #expect(CalendarDay(storageValue: 20_271_340) == nil)
    #expect(CalendarDay(storageValue: 20_270_230) == nil)
}

@Test func scanAtOneMinuteToMidnightCountsThatDay() {
    let date = localDate(2026, 10, 12, hour: 23, minute: 59)
    #expect(CalendarDay(date, in: cal) == CalendarDay(year: 2026, month: 10, day: 12))
}

@Test func daysUntilCountsCalendarDaysAcrossDaylightSavingChange() {
    let start = CalendarDay(year: 2026, month: 10, day: 30)
    let end = CalendarDay(year: 2026, month: 11, day: 3)
    #expect(start.days(until: end, in: cal) == 4)
    #expect(end.days(until: start, in: cal) == -4)
}

@Test func addingDaysCrossesMonthAndYear() {
    let day = CalendarDay(year: 2026, month: 12, day: 30)
    #expect(day.adding(days: 3, in: cal) == CalendarDay(year: 2027, month: 1, day: 2))
    #expect(day.adding(days: -30, in: cal) == CalendarDay(year: 2026, month: 11, day: 30))
}

@Test func dateIsStartOfDayAndDaysAreOrdered() {
    let day = CalendarDay(year: 2026, month: 11, day: 1)
    let date = day.date(in: cal)
    #expect(cal.dateComponents([.hour, .minute, .day], from: date) == DateComponents(day: 1, hour: 0, minute: 0))
    #expect(day < CalendarDay(year: 2026, month: 11, day: 2))
    #expect(CalendarDay(year: 2026, month: 12, day: 1) > CalendarDay(year: 2026, month: 11, day: 30))
}

@Test func fixedClockReportsToday() {
    let date = localDate(2026, 3, 3, hour: 22)
    let clock = AppClock.fixed(date, calendar: cal)
    #expect(clock.today == CalendarDay(year: 2026, month: 3, day: 3))
    #expect(clock.now() == date)
    #expect(clock.locale.identifier == "en_US")
}
