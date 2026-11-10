import Core
import Foundation
import Library
import Observation

/// What a grid shows: a collection's scans, Recent or All Scans, newest first (Favorites in its own order), with Select for several at once and Move
/// to Trash for them (#68, as Trash's select mode). Expired scans are hidden (M5); everything is read from the library
/// and from `Today`, so the grid moves when either does, and a scan that leaves the grid leaves the selection.
@Observable
public final class CollectionGridModel {
    /// Wallet's scans are cards; every other grid shows pages.
    package enum TileShape {
        case card
        case page
    }

    /// The shelf and what it was built from.
    private struct BuiltShelf {
        let scans: [ScanSummary]
        let lifespans: CollectionLifespans
        let day: CalendarDay
        let shelf: LibraryShelf
    }

    package let kind: GridKind
    /// Set when Move to Trash fails to save; the move changed nothing (M18).
    package private(set) var editAlert: EditAlert?

    private var selection = ScanSelection()
    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    @ObservationIgnored private let analytics: any Analytics
    @ObservationIgnored private var builtShelf: BuiltShelf?

    public init(kind: GridKind, library: any ScanLibrary, today: Today, calendar: Calendar, analytics: any Analytics) {
        self.kind = kind
        self.library = library
        self.today = today
        self.calendar = calendar
        self.analytics = analytics
    }

    package var title: String {
        switch kind {
        case .collection(let collection): CollectionText.name(collection)
        case .recent: CollectionText.recent
        case .all: CollectionText.allScans
        case .favorites: CollectionText.favorites
        }
    }

    /// The count (and lifespan) or "Last 30 days"; "2 selected" while selecting (M24).
    package var subtitle: String {
        if isSelecting { return ScanSelection.selectedLine(selected.count) }
        return switch kind {
        case .collection(let collection):
            CollectionText.scanCountAndLifespan(scans(on: shelf).count, shelf.lifespans[collection])
        case .recent:
            CollectionText.lastThirtyDays
        case .all, .favorites:
            CollectionText.scanCount(scans(on: shelf).count)
        }
    }

    package var tiles: [GridTile] {
        let shelf = shelf
        // Localizing is what costs here (about 50 ms for 2,000 tiles when each one looked up its own), and only a
        // handful of different strings exist.
        var names: [BuiltInCollection: String] = [:]
        var timeLefts: [TimeLeft: String] = [:]
        return scans(on: shelf).map { scan in
            let left = shelf.timeLeft(scan)
            let timeLeft = timeLefts[left] ?? TimeLeftText.text(left)
            timeLefts[left] = timeLeft
            let collectionName = names[scan.collection] ?? CollectionText.name(scan.collection)
            names[scan.collection] = collectionName
            return GridTile(
                id: scan.id,
                title: scan.title,
                collectionName: collectionName,
                timeLeft: timeLeft,
                isSoon: shelf.isSoon(scan),
                dot: showsWideScansWhole ? scan.collection : nil,
                isFavorite: scan.isFavorite
            )
        }
    }

    /// The grids that mix collections hold wide cards among tall pages, so a wide scan shows whole there (05-04,
    /// Collection.dc.html line 209). The same grids mark each tile with its collection's dot.
    package var showsWideScansWhole: Bool { kind.preselection == nil }

    package var isEmpty: Bool { scans(on: shelf).isEmpty }
    package var emptyTitle: String { CollectionText.emptyTitle(kind) }
    package var emptyBody: String { CollectionText.emptyBody(kind) }

    package var tileShape: TileShape { kind == .collection(.wallet) ? .card : .page }

    /// 3, or 2 at large text; Wallet 2, or 1 (requirements 06 · Accessibility).
    package func columns(largeText: Bool) -> Int {
        switch tileShape {
        case .card: largeText ? 1 : 2
        case .page: largeText ? 2 : 3
        }
    }

    // MARK: Select

    package var isSelecting: Bool { selection.isSelecting }

    /// The ticked scans the grid still shows.
    package var selected: Set<ScanID> { selection.selected(among: scans(on: shelf).map(\.id)) }

    /// Move to Trash is off until a scan is ticked (M24).
    package var canAct: Bool { !selected.isEmpty }

    /// "Move to Trash", or "Move 2 to Trash" for several, as Trash's "Delete 2".
    package var moveTitle: String {
        selected.count > 1
            ? String(localized: "Move \(selected.count) to Trash", bundle: #bundle)
            : String(localized: "Move to Trash", bundle: #bundle)
    }

    /// The confirmation's message (06-04's, for any count).
    package var moveMessage: String {
        let collections = Set(scans(on: shelf).filter { selected.contains($0.id) }.map(\.collection))
        return MoveToTrashText.message(
            count: selected.count, collection: collections.count == 1 ? collections.first : nil)
    }

    /// Select / Cancel; leaving forgets the ticks.
    public func toggleSelecting() {
        selection.toggleSelecting()
    }

    public func toggle(_ id: ScanID) {
        selection.toggle(id)
    }

    /// The confirmation's Move to Trash: the selected scans go to Trash and select mode ends. Returns what VoiceOver
    /// announces (M19), or nil when nothing was selected or the move failed to save (the alert shows).
    @discardableResult
    package func moveSelectedToTrash() -> String? {
        let scans = scans(on: shelf).filter { selected.contains($0.id) }
        guard !scans.isEmpty else { return nil }
        do {
            try library.moveToTrash(scans.map(\.id))
        } catch {
            editAlert = EditAlert()
            return nil
        }
        // One event per scan, as from the viewer: each carries its collection.
        for scan in scans { analytics.send(.scanMovedToTrash(collection: scan.collection)) }
        selection.finish()
        return MoveToTrashText.announcement(count: scans.count)
    }

    /// A tile's VoiceOver Favorite or Remove from Favorites: flips the scan's heart. A failed write shows the edit
    /// alert and changes nothing (P2).
    package func toggleFavorite(_ id: ScanID) {
        guard let scan = scans(on: shelf).first(where: { $0.id == id }) else { return }
        let isFavorite = !scan.isFavorite
        do {
            try library.setFavorite(isFavorite, for: [id])
        } catch {
            editAlert = EditAlert()
            return
        }
        analytics.send(.favoritesChanged(isFavorite: isFavorite, count: 1))
    }

    /// The edit alert's OK.
    package func dismissEditAlert() {
        editAlert = nil
    }

    // MARK: Private

    /// Built once per update: a body reads the model several times, and the library and day only change between
    /// updates. Reading them all here is what keeps the observation.
    private var shelf: LibraryShelf {
        let scans = library.scans
        let lifespans = library.lifespans
        let day = today.day
        if let builtShelf, builtShelf.scans == scans, builtShelf.lifespans == lifespans, builtShelf.day == day {
            return builtShelf.shelf
        }
        let shelf = LibraryShelf(scans: scans, lifespans: lifespans, today: day, calendar: calendar)
        builtShelf = BuiltShelf(scans: scans, lifespans: lifespans, day: day, shelf: shelf)
        return shelf
    }

    private func scans(on shelf: LibraryShelf) -> [ScanSummary] {
        switch kind {
        case .collection(let collection): shelf.in(collection)
        case .recent: shelf.recent
        case .all: shelf.visible
        case .favorites: shelf.favorites
        }
    }
}
