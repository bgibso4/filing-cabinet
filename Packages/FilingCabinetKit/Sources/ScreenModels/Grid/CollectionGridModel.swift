import Core
import Foundation
import Library
import Observation

/// What a grid shows: a collection's scans, Recent or All Scans, newest first (Favorites in its own order), with Select
/// for several at once and Move to Trash for them (#68, as Trash's select mode). Expired scans are hidden (M5);
/// everything is read from the library and from `Today`, so the grid moves when either does, and a scan that leaves
/// the grid leaves the selection. A scan taken out of Favorites while Favorites is on screen keeps its tile, with an
/// empty heart, until the screen goes (M9): this model lives as long as the screen.
@Observable
public final class CollectionGridModel {
    /// Wallet's scans are cards; every other grid shows pages.
    package enum TileShape {
        case card
        case page
    }

    /// The shelf, the grid's scans on it, and what both were built from.
    private struct BuiltShelf {
        let scans: [ScanSummary]
        let lifespans: CollectionLifespans
        let day: CalendarDay
        let shelf: LibraryShelf
        /// What the grid shows, in order.
        let shown: [ScanSummary]
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
    /// Favorites only: the tiles as last shown, so a scan taken out of Favorites keeps its place (M9).
    @ObservationIgnored private var lastShown: [ScanID] = []

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
        let built = built
        return switch kind {
        case .collection(let collection):
            CollectionText.scanCountAndLifespan(built.shown.count, built.lifespans[collection])
        case .recent:
            CollectionText.lastThirtyDays
        case .all:
            CollectionText.scanCount(built.shown.count)
        case .favorites:
            // Live: a tile kept with an empty heart isn't counted (M9).
            CollectionText.scanCount(built.shelf.favorites.count)
        }
    }

    package var tiles: [GridTile] {
        let built = built
        let shelf = built.shelf
        // Localizing is what costs here (about 50 ms for 2,000 tiles when each one looked up its own), and only a
        // handful of different strings exist.
        var names: [BuiltInCollection: String] = [:]
        var timeLefts: [TimeLeft: String] = [:]
        // Where each favourite stands among the favourites, for VoiceOver's moves; none outside Favorites or while
        // selecting (P5).
        let movable = kind == .favorites && !isSelecting ? Self.favoriteIDs(built.shown) : []
        let positions = Dictionary(uniqueKeysWithValues: movable.enumerated().map { ($1, $0) })
        return built.shown.map { scan in
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
                isFavorite: scan.isFavorite,
                // Only Favorites shows a scan that isn't one: a tile it keeps (M9).
                isUnfavorited: kind == .favorites && !scan.isFavorite,
                canMoveEarlier: positions[scan.id].map { $0 > 0 } ?? false,
                canMoveLater: positions[scan.id].map { $0 < movable.count - 1 } ?? false
            )
        }
    }

    /// The grids that mix collections hold wide cards among tall pages, so a wide scan shows whole there (05-04,
    /// Collection.dc.html line 209). The same grids mark each tile with its collection's dot.
    package var showsWideScansWhole: Bool { kind.preselection == nil }

    package var isEmpty: Bool { built.shown.isEmpty }
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
    package var selected: Set<ScanID> { selection.selected(among: built.shown.map(\.id)) }

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
        let collections = Set(built.shown.filter { selected.contains($0.id) }.map(\.collection))
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
        let scans = built.shown.filter { selected.contains($0.id) }
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
    /// alert and changes nothing (P2). In Favorites, a kept tile favourited again goes back to its place rather than
    /// last, so a slip is one tap to undo (M9): a second write. Should only that one fail, the alert shows and the scan
    /// stays a favourite, last.
    package func toggleFavorite(_ id: ScanID) {
        let shown = built.shown
        guard let scan = shown.first(where: { $0.id == id }) else { return }
        let isFavorite = !scan.isFavorite
        do {
            try library.setFavorite(isFavorite, for: [id])
        } catch {
            editAlert = EditAlert()
            return
        }
        analytics.send(.favoritesChanged(isFavorite: isFavorite, count: 1))
        guard isFavorite && kind == .favorites else { return }
        do {
            try library.reorderFavorites(shown.filter { $0.isFavorite || $0.id == id }.map(\.id))
        } catch {
            editAlert = EditAlert()
        }
    }

    /// A drop in Favorites (M8): the tiles `sources` go just before `destination` (nil: at the end), and the store
    /// takes the favourites' new order (M3). A kept tile isn't a favourite (M9), so the store leaves it out and it
    /// stays in its place. A failed write shows the edit alert and changes nothing.
    package func moveFavorites(_ sources: [ScanID], before destination: ScanID?) {
        let order = FavoriteReorder.order(built.shown.map(\.id), moving: sources, before: destination)
        do {
            try library.reorderFavorites(order)
        } catch {
            editAlert = EditAlert()
        }
    }

    /// VoiceOver's Move earlier: the favourite swaps places with the favourite before it (a kept tile isn't one).
    package func moveFavoriteEarlier(_ id: ScanID) {
        let favorites = Self.favoriteIDs(built.shown)
        guard let index = favorites.firstIndex(of: id), index > 0 else { return }
        moveFavorites([id], before: favorites[index - 1])
    }

    /// VoiceOver's Move later: the favourite swaps places with the favourite after it.
    package func moveFavoriteLater(_ id: ScanID) {
        let favorites = Self.favoriteIDs(built.shown)
        guard let index = favorites.firstIndex(of: id), index < favorites.count - 1 else { return }
        moveFavorites([id], before: favorites.indices.contains(index + 2) ? favorites[index + 2] : nil)
    }

    /// The edit alert's OK.
    package func dismissEditAlert() {
        editAlert = nil
    }

    // MARK: Private

    /// Built once per update: a body reads the model several times, and the library and day only change between
    /// updates. Reading them all here is what keeps the observation.
    private var built: BuiltShelf {
        let scans = library.scans
        let lifespans = library.lifespans
        let day = today.day
        if let builtShelf, builtShelf.scans == scans, builtShelf.lifespans == lifespans, builtShelf.day == day {
            return builtShelf
        }
        let shelf = LibraryShelf(scans: scans, lifespans: lifespans, today: day, calendar: calendar)
        let built = BuiltShelf(
            scans: scans, lifespans: lifespans, day: day, shelf: shelf, shown: shown(on: shelf))
        builtShelf = built
        // The one place Favorites remembers what it showed (M9).
        if kind == .favorites { lastShown = built.shown.map(\.id) }
        return built
    }

    private func shown(on shelf: LibraryShelf) -> [ScanSummary] {
        switch kind {
        case .collection(let collection): return shelf.in(collection)
        case .recent: return shelf.recent
        case .all: return shelf.visible
        case .favorites:
            return Self.keepingUnfavorited(shelf.favorites, lastShown: lastShown, visible: shelf.visible)
        }
    }

    /// The favourites among `shown`, in its order.
    private static func favoriteIDs(_ shown: [ScanSummary]) -> [ScanID] {
        shown.filter(\.isFavorite).map(\.id)
    }

    /// Favorites' tiles: the favourites in their order, with each scan shown before but no longer a favourite put back
    /// at its old index, while it is still in the library (M9).
    private static func keepingUnfavorited(
        _ favorites: [ScanSummary], lastShown: [ScanID], visible: [ScanSummary]
    ) -> [ScanSummary] {
        let favoriteIDs = Set(favorites.map(\.id))
        let visibleByID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
        var shown = favorites
        for (index, id) in lastShown.enumerated() where !favoriteIDs.contains(id) {
            guard let kept = visibleByID[id] else { continue }
            shown.insert(kept, at: min(index, shown.count))
        }
        return shown
    }
}
