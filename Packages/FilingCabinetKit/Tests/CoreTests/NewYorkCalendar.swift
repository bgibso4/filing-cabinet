import Foundation

/// Gregorian calendar in America/New_York, where daylight saving ended on Nov 1 2026.
let cal: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    guard let zone = TimeZone(identifier: "America/New_York") else { preconditionFailure("tz database missing") }
    calendar.timeZone = zone
    return calendar
}()

func localDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    guard let date = cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    else { preconditionFailure("invalid date") }
    return date
}
