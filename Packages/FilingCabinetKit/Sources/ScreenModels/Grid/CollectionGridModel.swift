import Core
import Foundation
import Library
import Observation

/// What a grid shows: a collection's scans, Recent or All Scans, newest first. Expired scans are hidden (M5);
/// everything is read from the library and from `Today`, so the grid moves when either does.
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

    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    @ObservationIgnored private var builtShelf: BuiltShelf?

    public init(kind: GridKind, library: any ScanLibrary, today: Today, calendar: Calendar) {
        self.kind = kind
        self.library = library
        self.today = today
        self.calendar = calendar
    }

    package var title: String {
        switch kind {
        case .collection(let collection): CollectionText.name(collection)
        case .recent: CollectionText.recent
        case .all: CollectionText.allScans
        }
    }

    package var subtitle: String {
        switch kind {
        case .collection(let collection):
            CollectionText.scanCountAndLifespan(scans(on: shelf).count, shelf.lifespans[collection])
        case .recent:
            CollectionText.lastThirtyDays
        case .all:
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
                dot: showsWideScansWhole ? scan.collection : nil
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
        }
    }
}
