import Core
import Foundation
import Library
import Observation

/// The Details sheet over the viewer (07-01 … 07-07): a scan's title, collection and expiry, each changed in place.
/// Everything is read from the library and from `Today`, so the sheet follows both; once the scan leaves the library
/// (a move to Trash, or midnight passing its last day) `isMissing` turns true and the sheet closes.
@Observable
package final class DetailsModel {
    /// The note under the collection row after a move; Undo lasts until the next edit (M17).
    package private(set) var movedNote: MovedNote?
    /// Set instead of moving when a move would send the scan to Trash.
    package private(set) var pendingTrashMove: TrashMoveAlert?
    /// Set when an edit fails to save; the edit changed nothing (M18).
    package private(set) var editAlert: EditAlert?

    /// The collection Undo moves back to.
    @ObservationIgnored private var collectionBeforeMove: BuiltInCollection?

    @ObservationIgnored private let id: ScanID
    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let today: Today
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let analytics: any Analytics

    package init(id: ScanID, library: any ScanLibrary, today: Today, clock: AppClock, analytics: any Analytics) {
        self.id = id
        self.library = library
        self.today = today
        self.clock = clock
        self.analytics = analytics
    }

    // MARK: Reading

    package var title: String { scan?.title ?? "" }
    package var collection: BuiltInCollection? { scan?.collection }
    package var collectionName: String { scan.map { CollectionText.name($0.collection) } ?? "" }

    /// "Scanned Oct 1, 2026 · 3 pages": always with the year (07-01).
    package var scannedLine: String {
        guard let scan else { return "" }
        let day = DayText.monthDayYear(CalendarDay(scan.scannedAt, in: clock.calendar), clock: clock)
        let pages = String(localized: "\(scan.pageCount) pages", bundle: #bundle)
        return String(localized: "Scanned \(day) · \(pages)", bundle: #bundle)
    }

    /// "Kept forever", or the last day and what is left of it: "Oct 16 · 5 days left".
    package var expiryValue: String {
        guard let scan else { return "" }
        let left = TimeLeftText.text(shelf.timeLeft(scan))
        guard let lastDay = scan.lastDay(lifespans: library.lifespans, in: clock.calendar) else { return left }
        let date = ExpiryText.untilDate(lastDay, today: today.day, clock: clock)
        return String(localized: "\(date) · \(left)", bundle: #bundle)
    }

    /// The expiry shows in orange.
    package var isExpirySoon: Bool { scan.map(shelf.isSoon) ?? false }

    package var collectionOptions: [CollectionOption] { CollectionOption.all(lifespans: library.lifespans) }

    /// Review's list, counted from the scan date; choices already passed are greyed and can't be chosen (M15).
    package var expiryOptions: [ExpiryOption] {
        guard let scan else { return [] }
        return ExpiryChoices(
            scanDay: CalendarDay(scan.scannedAt, in: clock.calendar),
            today: today.day,
            lifespans: library.lifespans,
            clock: clock
        )
        .options(collection: scan.collection, override: scan.expiryOverride)
    }

    /// Gone, in Trash or expired: the sheet closes.
    package var isMissing: Bool { scan == nil }

    // MARK: Title

    /// Trimmed; a blank title keeps the one there is (M16).
    package func rename(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scan, !trimmed.isEmpty, trimmed != scan.title else { return }
        if edit(.title, { () throws(LibraryError) in try library.rename(id, to: trimmed) }) {
            endUndo()
        }
    }

    // MARK: Collection

    /// Moves the scan, offering Undo. A move that would send it to Trash asks first (`pendingTrashMove`).
    package func choose(_ collection: BuiltInCollection) {
        guard let scan, collection != scan.collection else { return }
        var moved = scan
        moved.collection = collection
        guard staysInLibrary(moved) else {
            pendingTrashMove = TrashMoveAlert(
                moving: scan, to: collection, lifespans: library.lifespans, today: today.day, clock: clock)
            return
        }
        guard move(to: collection) else { return }
        collectionBeforeMove = scan.collection
        movedNote = scan.expiryOverride == nil ? .follows(CollectionText.name(collection)) : .keepsOwn
    }

    /// Moves the scan back where it was before the last move.
    package func undoMove() {
        guard let previous = collectionBeforeMove, move(to: previous) else { return }
        endUndo()
    }

    /// The alert's Move: the scan goes to Trash and the sheet closes.
    package func confirmTrashMove() {
        guard let pending = pendingTrashMove else { return }
        pendingTrashMove = nil
        if move(to: pending.collection) { endUndo() }
    }

    /// The alert's Cancel: nothing changes.
    package func cancelTrashMove() {
        pendingTrashMove = nil
    }

    // MARK: Expiry

    /// Nil is the collection default. A choice already passed is ignored.
    package func chooseExpiry(_ override: ExpiryOverride?) {
        guard let scan, override != scan.expiryOverride else { return }
        var changed = scan
        changed.expiryOverride = override
        guard staysInLibrary(changed) else { return }
        if edit(.expiry, { () throws(LibraryError) in try library.setExpiry(override, for: id) }) {
            endUndo()
        }
    }

    /// Keeps the scan through the end of `date`'s day. A day before today is refused.
    package func chooseExpiryDate(_ date: Date) {
        chooseExpiry(.lastDay(CalendarDay(date, in: clock.calendar)))
    }

    // MARK: Private

    /// The scan while it is in the library.
    private var scan: ScanSummary? { shelf.visible.first }

    private var shelf: LibraryShelf {
        LibraryShelf(
            scans: library.scans.filter { $0.id == id },
            lifespans: library.lifespans,
            today: today.day,
            calendar: clock.calendar)
    }

    /// Whether a changed copy of the scan would still be in the library today.
    private func staysInLibrary(_ changed: ScanSummary) -> Bool {
        guard case .library = changed.place(lifespans: library.lifespans, today: today.day, in: clock.calendar) else {
            return false
        }
        return true
    }

    private func move(to collection: BuiltInCollection) -> Bool {
        edit(.collection) { () throws(LibraryError) in try library.move(id, to: collection) }
    }

    /// Runs one edit; a failure shows the alert, anything else is reported.
    private func edit(_ field: EditedField, _ change: () throws(LibraryError) -> Void) -> Bool {
        do {
            try change()
        } catch {
            editAlert = EditAlert()
            return false
        }
        analytics.send(.scanEdited(field: field))
        return true
    }

    private func endUndo() {
        movedNote = nil
        collectionBeforeMove = nil
    }
}
