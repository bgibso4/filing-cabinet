import Testing

@testable import Core

private func day(_ month: Int, _ dayOfMonth: Int, year: Int = 2026) -> CalendarDay {
    CalendarDay(year: year, month: month, day: dayOfMonth)
}

private func place(last: CalendarDay?, trashed: CalendarDay? = nil, today: CalendarDay) -> ScanPlace {
    Lifecycle.place(lastDay: last, trashedDay: trashed, today: today, in: cal)
}

@Test func throwawayEntersTrashTheDayAfterItsLastDay() {
    let last = day(10, 18)
    #expect(place(last: last, today: day(10, 18)) == .library(.days(1)))
    #expect(place(last: last, today: day(10, 19)) == .trash(daysLeft: 30, entered: day(10, 19)))
}

@Test func trashLastsThirtyDaysCountingTheEntryDay() {
    let last = day(10, 18)
    #expect(place(last: last, today: day(11, 17)) == .trash(daysLeft: 1, entered: day(10, 19)))
    #expect(place(last: last, today: day(11, 18)) == .gone)
}

@Test func storedTrashDayWins() {
    #expect(place(last: nil, trashed: day(10, 20), today: day(10, 19)) == .library(.forever))
    #expect(place(last: nil, trashed: day(10, 20), today: day(10, 20)) == .trash(daysLeft: 30, entered: day(10, 20)))
}

@Test func foreverNeverEntersTrashOnItsOwn() {
    #expect(Lifecycle.entryDay(lastDay: nil, trashedDay: nil, in: cal) == nil)
    #expect(place(last: nil, today: day(1, 1, year: 2040)) == .library(.forever))
}

@Test func entryDayIsTheStoredDayElseTheDayAfterTheLastDay() {
    #expect(Lifecycle.entryDay(lastDay: day(10, 18), trashedDay: nil, in: cal) == day(10, 19))
    #expect(Lifecycle.entryDay(lastDay: day(10, 18), trashedDay: day(10, 5), in: cal) == day(10, 5))
}

@Test func trashAcrossDaylightSavingCountsCalendarDays() {
    // Daylight saving ended Nov 1 2026, inside this stretch.
    #expect(place(last: nil, trashed: day(10, 30), today: day(11, 3)) == .trash(daysLeft: 26, entered: day(10, 30)))
}

@Test func trashSoonIsTheLastSeven() {
    #expect(Lifecycle.isTrashSoon(daysLeft: 8) == false)
    #expect(Lifecycle.isTrashSoon(daysLeft: 7))
    #expect(Lifecycle.isTrashSoon(daysLeft: 1))
}
