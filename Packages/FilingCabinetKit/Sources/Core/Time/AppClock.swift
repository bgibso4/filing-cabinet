import Foundation

/// The time, calendar and locale the app reads. Injected so tests never touch the real clock.
public struct AppClock: Sendable {
    public let now: @Sendable () -> Date
    public let calendar: Calendar
    public let locale: Locale

    public init(now: @escaping @Sendable () -> Date, calendar: Calendar, locale: Locale) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    /// Always Gregorian, because `CalendarDay.storageValue` is validated as Gregorian: a Buddhist or Hebrew
    /// device calendar would store days that decode to nil. The time zone follows the device, so "today"
    /// does not go stale after a zone change.
    public static let system = Self(
        now: { Date() }, calendar: systemCalendar, locale: Locale(identifier: "en_US"))

    private static var systemCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    public static func fixed(_ date: Date, calendar: Calendar, locale: Locale = Locale(identifier: "en_US")) -> Self {
        Self(now: { date }, calendar: calendar, locale: locale)
    }

    public var today: CalendarDay { CalendarDay(now(), in: calendar) }
}
