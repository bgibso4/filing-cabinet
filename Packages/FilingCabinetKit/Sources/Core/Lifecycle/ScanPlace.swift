/// Where a scan is on a given day.
package enum ScanPlace: Sendable, Hashable {
    /// In the library, with what is left of its life.
    case library(TimeLeft)
    /// In Trash since `entered`, with this many days left including today.
    case trash(daysLeft: Int, entered: CalendarDay)
    /// Past Trash: to be deleted for good.
    case gone
}
