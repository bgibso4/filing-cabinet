import Core
import Foundation
import Library

/// Asks before a collection move that would send the scan to Trash (07-07): "Move to Throwaways?"
package struct TrashMoveAlert: Equatable {
    package let title: String
    package let message: String
    /// Where the scan moves if the person confirms.
    let collection: BuiltInCollection

    /// "Throwaways are kept 1 week from the scan date. This receipt is from Jul 19, so it goes to Trash now. You can
    /// restore it for 30 days."
    init(
        moving scan: ScanSummary,
        to collection: BuiltInCollection,
        lifespans: CollectionLifespans,
        today: CalendarDay,
        clock: AppClock
    ) {
        let name = CollectionText.name(collection)
        let kept = CollectionText.lifespanShort(lifespans[collection])
        let noun = CollectionText.noun(scan.collection, count: 1)
        // "Jul 19", with the year when it isn't this one.
        let scanned = ExpiryText.untilDate(CalendarDay(scan.scannedAt, in: clock.calendar), today: today, clock: clock)
        title = String(localized: "Move to \(name)?", bundle: #bundle)
        message = String(
            localized: """
                \(name) are kept \(kept) from the scan date. This \(noun) is from \(scanned), so it goes to Trash \
                now. You can restore it for \(Lifecycle.trashDays) days.
                """,
            bundle: #bundle)
        self.collection = collection
    }
}
