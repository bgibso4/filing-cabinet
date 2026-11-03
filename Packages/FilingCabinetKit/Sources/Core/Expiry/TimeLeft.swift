import Foundation

/// What is left of a scan's life on a given day.
public enum TimeLeft: Sendable, Equatable {
    case forever
    case days(Int)
    case expired

    /// Days left including `today`; zero or below is expired.
    public static func on(_ today: CalendarDay, lastDay: CalendarDay?, in calendar: Calendar) -> Self {
        guard let lastDay else { return .forever }
        let left = today.days(until: lastDay, in: calendar) + 1
        return left <= 0 ? .expired : .days(left)
    }

    /// Orange in the last 7 days; when the whole lifespan is 7 days or less, only on the last day.
    /// `spanDays` is `scanDay.days(until: lastDay) + 1`.
    public static func isSoon(daysLeft: Int, spanDays: Int) -> Bool {
        spanDays > 7 ? daysLeft <= 7 : daysLeft <= 1
    }
}
