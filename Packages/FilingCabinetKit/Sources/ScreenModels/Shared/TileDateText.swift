import Core
import Foundation

/// A grid tile's second line: the scan's day and a short time left, "Nov 11 · 3 mo left", so a wall of receipts tells
/// apart. Rules as `TimeLeftText`: a year or more counts years, two months or more months, else days.
enum TileDateText {
    static func text(scanDay: CalendarDay, left: TimeLeft, clock: AppClock) -> String {
        let day = DayText.monthDay(scanDay, clock: clock)
        return switch left {
        case .forever:
            String(localized: "\(day) · Forever", bundle: #bundle)
        case .expired:
            String(localized: "\(day) · \(0)d left", bundle: #bundle)
        case .days(let days) where days >= 365:
            String(localized: "\(day) · \(days / 365) yr left", bundle: #bundle)
        case .days(let days) where days >= 60:
            String(localized: "\(day) · \(days / 30) mo left", bundle: #bundle)
        case .days(let days):
            String(localized: "\(day) · \(days)d left", bundle: #bundle)
        }
    }
}
