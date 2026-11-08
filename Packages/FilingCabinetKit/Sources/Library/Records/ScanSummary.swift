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
    /// The Trash day to store when a change (collection, expiry or lifespan) moves the scan's last day to
    /// `newLastDay` (M1). `lifespans` are the ones before the change. A scan already in Trash keeps its entry day,
    /// stored only when the change would move it, so one that entered on its own still reads that way (M4, M9); one
    /// the change expires enters Trash today, with the full 30 days; any other keeps what it has.
    package func trashedDay(
        afterLastDayChangesTo newLastDay: CalendarDay?,
        lifespans: CollectionLifespans,
        today: CalendarDay,
        in calendar: Calendar
    ) -> CalendarDay? {
        let lastDayNow = lastDay(lifespans: lifespans, in: calendar)
        guard case .library = Lifecycle.place(lastDay: lastDayNow, trashedDay: trashedDay, today: today, in: calendar)
        else {
            let entryDay = Lifecycle.entryDay(lastDay: lastDayNow, trashedDay: trashedDay, in: calendar)
            let entryDayAfter = Lifecycle.entryDay(lastDay: newLastDay, trashedDay: trashedDay, in: calendar)
            return entryDayAfter == entryDay ? trashedDay : entryDay
        }
        guard case .library = Lifecycle.place(lastDay: newLastDay, trashedDay: trashedDay, today: today, in: calendar)
        else { return today }
        return trashedDay
    }

    /// The Trash day to store when the collection lifespans change from `lifespans` to `newLifespans` (M1).
    package func trashedDay(
        afterLifespansChangeTo newLifespans: CollectionLifespans,
        from lifespans: CollectionLifespans,
        today: CalendarDay,
        in calendar: Calendar
    ) -> CalendarDay? {
        trashedDay(
            afterLastDayChangesTo: lastDay(lifespans: newLifespans, in: calendar),
            lifespans: lifespans,
            today: today,
            in: calendar)
    }

    /// Whether changing the collection lifespans from `lifespans` to `newLifespans` sends this scan from the
    /// library to Trash today (M1).
    package func entersTrash(
        ifLifespansChangeTo newLifespans: CollectionLifespans,
        from lifespans: CollectionLifespans,
        today: CalendarDay,
        in calendar: Calendar
    ) -> Bool {
        guard case .library = place(lifespans: lifespans, today: today, in: calendar) else { return false }
        return trashedDay(afterLifespansChangeTo: newLifespans, from: lifespans, today: today, in: calendar) == today
    }

    /// Where the scan is on `today` under `lifespans`.
    package func place(lifespans: CollectionLifespans, today: CalendarDay, in calendar: Calendar) -> ScanPlace {
        Lifecycle.place(
            lastDay: lastDay(lifespans: lifespans, in: calendar), trashedDay: trashedDay, today: today, in: calendar)
    }

    /// The scan's last day under `lifespans`; nil when it is kept forever.
    package func lastDay(lifespans: CollectionLifespans, in calendar: Calendar) -> CalendarDay? {
        Expiry.lastDay(
            scanDay: CalendarDay(scannedAt, in: calendar),
            collectionLifespan: lifespans[collection],
            override: expiryOverride,
            in: calendar)
    }
}
