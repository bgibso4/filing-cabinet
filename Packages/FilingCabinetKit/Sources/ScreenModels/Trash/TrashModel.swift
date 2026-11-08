import Core
import Foundation
import Library
import Observation

/// The Trash screen (09-01 … 09-11): scans soonest gone first, Select for several at once, Restore, Delete and Empty
/// Trash. Everything is read from the library and from `Today`, so a scan that leaves Trash overnight leaves the
/// tiles and the selection with it.
@Observable
public final class TrashModel {
    /// Set by Delete and Empty Trash; nothing is removed until `performConfirmation(_:)`.
    package private(set) var confirmation: TrashConfirmation?
    /// Set when a write fails; the action changed nothing (M18).
    package private(set) var editAlert: EditAlert?
    package private(set) var isSelecting = false

    /// What was ticked; `selected` drops any scan no longer in Trash.
    private var ticked: Set<ScanID> = []

    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let today: Today
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let analytics: any Analytics

    public init(library: any ScanLibrary, today: Today, calendar: Calendar, analytics: any Analytics) {
        self.library = library
        self.today = today
        self.calendar = calendar
        self.analytics = analytics
    }

    // MARK: Reading

    package var tiles: [TrashTile] {
        let shelf = shelf
        return shelf.trash.map { scan in
            let daysLeft = shelf.trashDaysLeft(scan)
            return TrashTile(
                id: scan.id,
                title: scan.title,
                collection: scan.collection,
                daysLeftText: TimeLeftText.text(.days(daysLeft)),
                isSoon: Lifecycle.isTrashSoon(daysLeft: daysLeft))
        }
    }

    package var isEmpty: Bool { shelf.trash.isEmpty }

    /// "7 scans · each is deleted after 30 days here", "2 selected" while selecting (M24); nil when empty.
    package var subtitle: String? {
        if isSelecting { return String(localized: "\(selected.count) selected", bundle: #bundle) }
        let count = shelf.trash.count
        guard count > 0 else { return nil }
        return String(
            localized: "\(CollectionText.scanCount(count)) · each is deleted after \(Lifecycle.trashDays) days here",
            bundle: #bundle)
    }

    /// The ticked scans that are still in Trash.
    package var selected: Set<ScanID> { ticked.intersection(shelf.trash.map(\.id)) }

    /// "Delete 2", or "Delete" for none or one.
    package var deleteTitle: String {
        selected.count > 1
            ? String(localized: "Delete \(selected.count)", bundle: #bundle)
            : String(localized: "Delete", bundle: #bundle)
    }

    package var restoreTitle: String {
        selected.count > 1
            ? String(localized: "Restore \(selected.count)", bundle: #bundle)
            : String(localized: "Restore", bundle: #bundle)
    }

    /// Delete and Restore are off until something is ticked.
    package var canAct: Bool { !selected.isEmpty }

    /// "To Throwaways, kept forever" (09-03).
    package func restoreLine(for id: ScanID) -> String {
        guard let scan = shelf.trash.first(where: { $0.id == id }) else { return "" }
        return String(localized: "To \(CollectionText.name(scan.collection)), kept forever", bundle: #bundle)
    }

    // MARK: Select

    /// Select / Cancel. Leaving select mode forgets the ticks.
    public func toggleSelecting() {
        isSelecting.toggle()
        ticked = []
    }

    public func toggle(_ id: ScanID) {
        guard isSelecting else { return }
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    // MARK: Actions

    /// Puts the scans back in their collections, kept forever; no confirmation (M10). Returns the text VoiceOver
    /// announces (M19), or nil when the write failed (the alert shows).
    @discardableResult
    package func restore(_ ids: [ScanID]) -> String? {
        let scans = shelf.trash.filter { ids.contains($0.id) }
        guard !scans.isEmpty else { return nil }
        do {
            try library.restore(scans.map(\.id))
        } catch {
            editAlert = EditAlert()
            return nil
        }
        analytics.send(.scansRestored(count: scans.count))
        finish()
        if let only = scans.first, scans.count == 1 {
            return String(localized: "Restored to \(CollectionText.name(only.collection))", bundle: #bundle)
        }
        return String(localized: "Restored \(scans.count) scans", bundle: #bundle)
    }

    /// Asks before deleting these scans for good.
    package func confirmDelete(_ ids: [ScanID]) {
        let scans = shelf.trash.filter { ids.contains($0.id) }
        guard let first = scans.first else { return }
        confirmation = TrashConfirmation(deleting: scans.map(\.id), firstTitle: first.title)
    }

    /// Asks before deleting everything in Trash.
    package func confirmEmpty() {
        let count = shelf.trash.count
        guard count > 0 else { return }
        confirmation = TrashConfirmation(emptying: count)
    }

    // Where the confirmation comes up from: the button that asked (Ben, 2026-11-08), and nowhere else.

    /// Empty Trash's, from Empty Trash.
    package var emptyConfirmation: TrashConfirmation? {
        confirmation?.action == .empty ? confirmation : nil
    }

    /// Delete N's, from Delete N while selecting (a tile's accessibility action asks from there too).
    package var selectionConfirmation: TrashConfirmation? {
        isSelecting && confirmation?.action != .empty ? confirmation : nil
    }

    /// A long-pressed tile's Delete now, from that tile.
    package func tileConfirmation(_ id: ScanID) -> TrashConfirmation? {
        !isSelecting && confirmation?.action == .delete([id]) ? confirmation : nil
    }

    package func cancelConfirmation() {
        confirmation = nil
    }

    /// Runs what this confirmation asked. It is the one the dialog presented, not `confirmation`: the dialog may clear
    /// that (`cancelConfirmation()`) as it goes, before its button's action runs. Returns the announcement (M19), or nil
    /// when the write failed.
    @discardableResult
    package func performConfirmation(_ asked: TrashConfirmation) async -> String? {
        let action = asked.action
        confirmation = nil
        let count: Int
        do {
            switch action {
            case .delete(let ids):
                try await library.deleteNow(ids)
                count = ids.count
                analytics.send(.scansDeleted(count: count))
            case .empty:
                count = try await library.emptyTrash()
                analytics.send(.trashEmptied(count: count))
            }
        } catch {
            editAlert = EditAlert()
            return nil
        }
        finish()
        return count == 1
            ? String(localized: "Deleted", bundle: #bundle)
            : String(localized: "Deleted \(count) scans", bundle: #bundle)
    }

    /// The edit alert's OK.
    package func dismissEditAlert() {
        editAlert = nil
    }

    // MARK: Private

    private var shelf: LibraryShelf {
        LibraryShelf(
            scans: library.scans, lifespans: library.lifespans, today: today.day, calendar: calendar)
    }

    /// An action ends select mode.
    private func finish() {
        isSelecting = false
        ticked = []
    }
}
