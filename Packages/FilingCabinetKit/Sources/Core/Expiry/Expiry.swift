import Foundation

/// When a scan's life ends. Every expiry ends at the end of its last day, and the scan day is day 1.
package enum Expiry {
    /// The last day the scan is kept, or nil for forever. A lifespan of N days gives `scanDay + (N - 1)`;
    /// a custom last day is used as is.
    package static func lastDay(
        scanDay: CalendarDay, collectionLifespan: Lifespan, override: ExpiryOverride?, in calendar: Calendar
    ) -> CalendarDay? {
        switch override {
        case .lastDay(let day):
            return day
        case .lifespan(let lifespan):
            return lastDay(scanDay: scanDay, lifespan: lifespan, in: calendar)
        case nil:
            return lastDay(scanDay: scanDay, lifespan: collectionLifespan, in: calendar)
        }
    }

    private static func lastDay(scanDay: CalendarDay, lifespan: Lifespan, in calendar: Calendar) -> CalendarDay? {
        lifespan.days.map { scanDay.adding(days: $0 - 1, in: calendar) }
    }
}
