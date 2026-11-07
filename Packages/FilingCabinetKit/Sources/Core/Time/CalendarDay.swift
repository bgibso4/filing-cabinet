import Foundation

/// A calendar day with no time of day, so "Oct 12" stays Oct 12 whatever the time zone or daylight saving.
public struct CalendarDay: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        // The calendar always fills year, month and day for a real date.
        self.init(year: parts.year ?? 1, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// yyyymmdd, e.g. 20270109.
    public var storageValue: Int { year * 10_000 + month * 100 + day }

    /// Nil when the value is not a real day (month 13, Feb 30, ...).
    public init?(storageValue: Int) {
        let candidate = Self(
            year: storageValue / 10_000, month: storageValue / 100 % 100, day: storageValue % 100)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0) ?? gregorian.timeZone
        let date = gregorian.date(
            from: DateComponents(year: candidate.year, month: candidate.month, day: candidate.day))
        guard let date, Self(date, in: gregorian) == candidate, storageValue > 0 else { return nil }
        self = candidate
    }

    /// The start of this day in `calendar`.
    public func date(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days count: Int, in calendar: Calendar) -> Self {
        let start = date(in: calendar)
        return Self(calendar.date(byAdding: .day, value: count, to: start) ?? start, in: calendar)
    }

    /// Whole calendar days from this day to `other` (negative when `other` is earlier). Never seconds.
    public func days(until other: Self, in calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: date(in: calendar), to: other.date(in: calendar)).day ?? 0
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.storageValue < rhs.storageValue
    }
}
