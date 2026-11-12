import Core
import Foundation
import Testing

@testable import ScreenModels

private let clock = AppClock.fixed(
    Date(timeIntervalSince1970: 1_790_000_000),
    calendar: Calendar(identifier: .gregorian),
    locale: Locale(identifier: "en_US"))

private func line(_ day: CalendarDay, _ left: TimeLeft) -> String {
    TileDateText.text(scanDay: day, left: left, clock: clock)
}

@Test func monthsUseMo() {
    #expect(line(CalendarDay(year: 2026, month: 11, day: 11), .days(95)) == "Nov 11 · 3 mo left")
    #expect(line(CalendarDay(year: 2026, month: 11, day: 11), .days(60)) == "Nov 11 · 2 mo left")
}

@Test func yearsUseYr() {
    #expect(line(CalendarDay(year: 2026, month: 9, day: 28), .days(730)) == "Sep 28 · 2 yr left")
}

@Test func daysUseD() {
    #expect(line(CalendarDay(year: 2026, month: 9, day: 28), .days(59)) == "Sep 28 · 59d left")
}

@Test func foreverHasNoLeft() {
    #expect(line(CalendarDay(year: 2026, month: 3, day: 4), .forever) == "Mar 4 · Forever")
}

@Test func expiredReadsZeroDays() {
    #expect(line(CalendarDay(year: 2026, month: 3, day: 4), .expired) == "Mar 4 · 0d left")
}
