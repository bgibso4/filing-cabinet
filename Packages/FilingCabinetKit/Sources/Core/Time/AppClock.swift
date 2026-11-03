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

    public static let system = Self(
        now: { Date() }, calendar: .current, locale: Locale(identifier: "en_US"))

    public static func fixed(_ date: Date, calendar: Calendar, locale: Locale = Locale(identifier: "en_US")) -> Self {
        Self(now: { date }, calendar: calendar, locale: locale)
    }

    public var today: CalendarDay { CalendarDay(now(), in: calendar) }
}
