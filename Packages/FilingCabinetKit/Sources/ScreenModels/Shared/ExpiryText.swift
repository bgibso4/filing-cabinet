import Core
import Foundation

/// Expiry dates as text.
enum ExpiryText {
    /// "Jan 9", or "Jan 9, 2027" when the year isn't today's.
    static func untilDate(_ day: CalendarDay, today: CalendarDay, clock: AppClock) -> String {
        DayText.monthDay(day, today: today, clock: clock)
    }

    /// The Review row's value: "3 months · until Jan 9", "Kept forever" or, for a chosen date, "Until Mar 3".
    static func reviewValue(
        collectionLifespan: Lifespan,
        override: ExpiryOverride?,
        scanDay: CalendarDay,
        today: CalendarDay,
        clock: AppClock
    ) -> String {
        let lifespan: Lifespan
        switch override {
        case .lastDay(let day):
            return String(
                localized: "Until \(untilDate(day, today: today, clock: clock))", bundle: #bundle)
        case .lifespan(let chosen):
            lifespan = chosen
        case nil:
            lifespan = collectionLifespan
        }
        let lastDay = Expiry.lastDay(
            scanDay: scanDay, collectionLifespan: collectionLifespan, override: override, in: clock.calendar)
        guard let lastDay else { return CollectionText.lifespanShort(.forever) }
        let date = untilDate(lastDay, today: today, clock: clock)
        return String(
            localized: "\(CollectionText.lifespanShort(lifespan)) · until \(date)", bundle: #bundle)
    }
}
