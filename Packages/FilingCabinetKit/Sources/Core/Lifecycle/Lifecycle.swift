import Foundation

/// The one rule for where a scan is (library, Trash or gone), from its dates alone.
package enum Lifecycle {
    /// Days a scan stays in Trash, counting the day it enters.
    package static let trashDays = 30

    /// The day a scan enters Trash: the stored `trashedDay`, else the day after its last day, else nil
    /// (forever and never trashed).
    package static func entryDay(lastDay: CalendarDay?, trashedDay: CalendarDay?, in calendar: Calendar) -> CalendarDay?
    {
        trashedDay ?? lastDay?.adding(days: 1, in: calendar)
    }

    package static func place(
        lastDay: CalendarDay?, trashedDay: CalendarDay?, today: CalendarDay, in calendar: Calendar
    ) -> ScanPlace {
        guard let entry = entryDay(lastDay: lastDay, trashedDay: trashedDay, in: calendar), today >= entry else {
            return .library(TimeLeft.on(today, lastDay: lastDay, in: calendar))
        }
        let lastTrashDay = entry.adding(days: trashDays - 1, in: calendar)
        let daysLeft = today.days(until: lastTrashDay, in: calendar) + 1
        return daysLeft > 0 ? .trash(daysLeft: daysLeft, entered: entry) : .gone
    }

    /// Trash shows a warning in the last 7 days.
    package static func isTrashSoon(daysLeft: Int) -> Bool { daysLeft <= 7 }
}
