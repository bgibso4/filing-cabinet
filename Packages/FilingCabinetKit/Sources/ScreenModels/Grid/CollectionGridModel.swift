import Core
import Foundation
import Library
import Observation

/// What a grid shows: a collection's scans, Recent or All Scans, newest first (Favorites in its own order), with Select
/// for several at once, and Share, Favorite and Move to Trash for them (#68, as Trash's select mode; B12). Expired
/// scans are hidden (M5); everything is read from the library and from `Today`, so the grid moves when either does,
/// and a scan that leaves the grid leaves the selection. A scan taken out of Favorites while Favorites is on screen
/// keeps its tile, with an empty heart, until the screen goes (M9): this model lives as long as the screen. Favorites'
/// ordering is in `CollectionGridModel+Favorites.swift`.
@Observable
public final class CollectionGridModel {
    /// Wallet's scans are cards; every other grid shows pages.
    package enum TileShape {
        case card
        case page
    }

    /// The shelf, the grid's scans on it, and what both were built from.
    struct BuiltShelf {
        let scans: [ScanSummary]
        let lifespans: CollectionLifespans
        let day: CalendarDay
        let shelf: LibraryShelf
        /// What the grid shows, in order.
        let shown: [ScanSummary]
    }

    private struct DetailKey: Hashable {
        let day: CalendarDay
        let left: TimeLeft
    }

    package let kind: GridKind
    /// Set when Move to Trash fails to save; the move changed nothing (M18).
    package internal(set) var editAlert: EditAlert?

    private var selection = ScanSelection()
    let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    @ObservationIgnored let analytics: any Analytics
    /// The PDFs the selection's Share made, which go when select mode ends or the grid goes (M20).
    @ObservationIgnored private let exported: ExportedFiles
    @ObservationIgnored private var builtShelf: BuiltShelf?
    /// Favorites only: the tiles as last shown, so a scan taken out of Favorites keeps its place (M9).
    @ObservationIgnored private var lastShown: [ScanID] = []

    /// `export` makes the PDFs the selection's Share sends.
    public init(
        kind: GridKind,
        library: any ScanLibrary,
        today: Today,
        calendar: Calendar,
        analytics: any Analytics,
        export: ScanExport
    ) {
        self.kind = kind
        self.library = library
        self.today = today
        self.calendar = calendar
        self.analytics = analytics
        exported = ExportedFiles(export: export)
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
        // Localizing the collection's name is what costs here (about 50 ms for 2,000 tiles when each one looked up its
        // own), and only a handful of different names exist.
        var names: [BuiltInCollection: String] = [:]
        // The date line costs the same (a date formatter each), and scans of one day with the same time left share it.
        var details: [DetailKey: String] = [:]
        // Where each favourite stands among the favourites, for VoiceOver's moves; none outside Favorites or while
        // selecting (P5).
        let movable = kind == .favorites && !isSelecting ? Self.favoriteIDs(built.shown) : []
        let positions = Dictionary(uniqueKeysWithValues: movable.enumerated().map { ($1, $0) })
        return built.shown.map { scan in
            let collectionName = names[scan.collection] ?? CollectionText.name(scan.collection)
            names[scan.collection] = collectionName
            let key = DetailKey(day: CalendarDay(scan.scannedAt, in: calendar), left: shelf.timeLeft(scan))
            let detail =
                details[key] ?? TileDateText.text(scanDay: key.day, left: key.left, clock: today.clock)
            details[key] = detail
            return GridTile(
                id: scan.id,
                title: scan.title,
                collectionName: collectionName,
                detail: detail,
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

    /// The pill's titles, longest first: "Move 2 to Trash" for several (as Trash's "Delete 2"), then "Move to Trash".
    /// The view shows the first that fits (B12); where "Move 387 to Trash" doesn't, the count stays in the subtitle.
    package var moveTitles: [String] {
        let count = selected.count
        let short = String(localized: "Move to Trash", bundle: #bundle)
        return count > 1 ? [String(localized: "Move \(count) to Trash", bundle: #bundle), short] : [short]
    }

    /// The confirmation's message (06-04's, for any count).
    package var moveMessage: String {
        let collections = Set(selectedScans.map(\.collection))
        return MoveToTrashText.message(
            count: selected.count, collection: collections.count == 1 ? collections.first : nil)
    }

    /// Select / Cancel; leaving forgets the ticks and the PDFs the selection shared.
    public func toggleSelecting() {
        if selection.isSelecting { exportEnded() }
        selection.toggleSelecting()
    }

    public func toggle(_ id: ScanID) {
        selection.toggle(id)
    }

    /// The confirmation's Move to Trash: the selected scans go to Trash and select mode ends. Returns what VoiceOver
    /// announces (M19), or nil when nothing was selected or the move failed to save (the alert shows).
    @discardableResult
    package func moveSelectedToTrash() -> String? {
        let scans = selectedScans
        guard !scans.isEmpty else { return nil }
        do {
            try library.moveToTrash(scans.map(\.id))
        } catch {
            editAlert = EditAlert()
            return nil
        }
        // One event per scan, as from the viewer: each carries its collection.
        for scan in scans { analytics.send(.scanMovedToTrash(collection: scan.collection)) }
        finishSelecting()
        return MoveToTrashText.announcement(count: scans.count)
    }

    /// The edit alert's OK.
    package func dismissEditAlert() {
        editAlert = nil
    }

    // MARK: Private (internal where CollectionGridModel+Favorites reads it)

    /// The ticked scans the grid still shows, in its order.
    private var selectedScans: [ScanSummary] {
        let selected = selected
        return built.shown.filter { selected.contains($0.id) }
    }

    /// An action ends select mode, and with it the selection's shared PDFs.
    private func finishSelecting() {
        selection.finish()
        exportEnded()
    }

    /// Built once per update: a body reads the model several times, and the library and day only change between
    /// updates. Reading them all here is what keeps the observation.
    var built: BuiltShelf {
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
}

// MARK: - The selection's Share and Favorite (B12)

extension CollectionGridModel {
    /// True when every selected scan is a favourite, so the bar's heart takes them out (B12).
    package var selectionIsFavorite: Bool {
        let scans = selectedScans
        return !scans.isEmpty && scans.allSatisfy(\.isFavorite)
    }

    /// "Favorite" while any selected scan isn't one, else "Remove from Favorites".
    package var favoriteTitle: String {
        selectionIsFavorite
            ? String(localized: "Remove from Favorites", bundle: #bundle)
            : String(localized: "Favorite", bundle: #bundle)
    }

    /// What Share sends (B7, M10): one PDF per selected scan, in the grid's order, reported once with the count.
    package var sharedPDFs: [ScanPDF] {
        let scans = selectedScans
        let event = AnalyticsEvent.scansExported(kind: .share, count: scans.count)
        return ScanPDF.sharing(scans, exported: exported, made: { [analytics] in analytics.send(event) })
    }

    /// The bar's heart: the selected scans become favourites, new ones last in the grid's order, or, when all of them
    /// are, stop being favourites. Select mode ends; the event counts the scans that changed. A failed write shows the
    /// edit alert and changes nothing. True when it saved.
    @discardableResult
    package func favoriteSelected() -> Bool {
        let scans = selectedScans
        guard !scans.isEmpty else { return false }
        let isFavorite = !selectionIsFavorite
        do {
            try library.setFavorite(isFavorite, for: scans.map(\.id))
        } catch {
            editAlert = EditAlert()
            return false
        }
        analytics.send(.favoritesChanged(isFavorite: isFavorite, count: scans.count { $0.isFavorite != isFavorite }))
        finishSelecting()
        return true
    }

    /// The grid has gone: the PDFs its selection shared are no longer needed (M20). Another screen's stay.
    package func exportEnded() {
        exported.removeAll()
    }
}
