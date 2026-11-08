import Core
import Foundation
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private func utcDate(_ day: Int, hour: Int, minute: Int = 0) -> Date {
    guard let date = utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))
    else { preconditionFailure("invalid date") }
    return date
}

@Test func refreshPicksUpANewDay() {
    let clockNow = MovableNow(utcDate(12, hour: 23, minute: 59))
    let today = Today(clock: AppClock(now: { clockNow.now }, calendar: utc, locale: Locale(identifier: "en_US")))
    #expect(today.day == CalendarDay(year: 2026, month: 10, day: 12))

    clockNow.set(utcDate(13, hour: 0, minute: 1))
    // Nothing changes until the app asks.
    #expect(today.day == CalendarDay(year: 2026, month: 10, day: 12))

    today.refresh()
    #expect(today.day == CalendarDay(year: 2026, month: 10, day: 13))
}

@Test func refreshOnTheSameDayKeepsTheDay() {
    let clockNow = MovableNow(utcDate(12, hour: 8))
    let today = Today(clock: AppClock(now: { clockNow.now }, calendar: utc, locale: Locale(identifier: "en_US")))
    clockNow.set(utcDate(12, hour: 20))
    today.refresh()
    #expect(today.day == CalendarDay(year: 2026, month: 10, day: 12))
}
