import Foundation
import Testing

@testable import Core

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)

@Test func receiptFromOct12LastsUntilJan9() {
    #expect(
        Expiry.lastDay(scanDay: oct12, collectionLifespan: .threeMonths, override: nil, in: cal)
            == CalendarDay(year: 2027, month: 1, day: 9))
}

@Test func customDateLastsThroughThatDay() {
    let mar3 = CalendarDay(year: 2027, month: 3, day: 3)
    let last = Expiry.lastDay(scanDay: oct12, collectionLifespan: .forever, override: .lastDay(mar3), in: cal)
    #expect(last == mar3)
    #expect(TimeLeft.on(mar3, lastDay: last, in: cal) == .days(1))
    #expect(TimeLeft.on(CalendarDay(year: 2027, month: 3, day: 4), lastDay: last, in: cal) == .expired)
}

@Test func overrideBeatsCollection() {
    let last = Expiry.lastDay(scanDay: oct12, collectionLifespan: .forever, override: .lifespan(.month), in: cal)
    #expect(last == oct12.adding(days: 29, in: cal))
}

@Test func overrideForeverBeatsCollectionLifespan() {
    #expect(Expiry.lastDay(scanDay: oct12, collectionLifespan: .week, override: .lifespan(.forever), in: cal) == nil)
}

@Test func foreverHasNoLastDay() {
    let last = Expiry.lastDay(scanDay: oct12, collectionLifespan: .forever, override: nil, in: cal)
    #expect(last == nil)
    #expect(TimeLeft.on(oct12, lastDay: last, in: cal) == .forever)
}
