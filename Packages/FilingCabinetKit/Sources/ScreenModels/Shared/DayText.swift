import Core
import Foundation

/// Calendar days as text, in the clock's locale and calendar, never the device region (M6).
enum DayText {
    /// "Oct 12".
    static func monthDay(_ day: CalendarDay, clock: AppClock) -> String {
        format(day, template: "MMMd", clock: clock)
    }

    /// "Jan 9, 2027".
    static func monthDayYear(_ day: CalendarDay, clock: AppClock) -> String {
        format(day, template: "MMMdy", clock: clock)
    }

    private static func format(_ day: CalendarDay, template: String, clock: AppClock) -> String {
        let formatter = DateFormatter()
        formatter.locale = clock.locale
        formatter.calendar = clock.calendar
        formatter.timeZone = clock.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: day.date(in: clock.calendar))
    }
}
