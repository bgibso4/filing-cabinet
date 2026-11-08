import Core
import Foundation

/// A Sendable snapshot of one scan, safe to hand across isolation and to the screens. Changing a copy changes
/// nothing in the library: edits go through `ScanLibrary`.
public struct ScanSummary: Sendable, Hashable, Identifiable {
    public let id: ScanID
    package var title: String
    package var collection: BuiltInCollection
    package let scannedAt: Date
    package var expiryOverride: ExpiryOverride?
    package let pageCount: Int
    /// The day the scan went to Trash; nil while it is in the library.
    package var trashedDay: CalendarDay?

    public init(
        id: ScanID,
        title: String,
        collection: BuiltInCollection,
        scannedAt: Date,
        expiryOverride: ExpiryOverride?,
        pageCount: Int,
        trashedDay: CalendarDay? = nil
    ) {
        self.id = id
        self.title = title
        self.collection = collection
        self.scannedAt = scannedAt
        self.expiryOverride = expiryOverride
        self.pageCount = pageCount
        self.trashedDay = trashedDay
    }
}

extension ScanSummary {
    /// The Trash day to store when the scan moves to `collection` (M1). A scan already in Trash keeps its entry
    /// day; one the move expires enters Trash today, with the full 30 days; any other keeps what it has.
    package func trashedDayAfterMoving(
        to collection: BuiltInCollection,
        lifespans: CollectionLifespans,
        today: CalendarDay,
        in calendar: Calendar
    ) -> CalendarDay? {
        let lastDayNow = lastDay(lifespan: lifespans[self.collection], in: calendar)
        guard case .library = Lifecycle.place(lastDay: lastDayNow, trashedDay: trashedDay, today: today, in: calendar)
        else {
            return Lifecycle.entryDay(lastDay: lastDayNow, trashedDay: trashedDay, in: calendar)
        }
        let lastDayAfter = lastDay(lifespan: lifespans[collection], in: calendar)
        guard case .library = Lifecycle.place(lastDay: lastDayAfter, trashedDay: trashedDay, today: today, in: calendar)
        else { return today }
        return trashedDay
    }

    private func lastDay(lifespan: Lifespan, in calendar: Calendar) -> CalendarDay? {
        Expiry.lastDay(
            scanDay: CalendarDay(scannedAt, in: calendar),
            collectionLifespan: lifespan,
            override: expiryOverride,
            in: calendar)
    }
}
