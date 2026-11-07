import Core
import Foundation
import Library
import Observation

/// What Home shows: the collections with their counts, and the Recent and All Scans views. With no visible scan
/// it shows the first-launch rows instead (M14). Expired scans are not counted (M5); everything is read from the
/// library and from `Today`, so the numbers move when either does.
@Observable
public final class HomeModel {
    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar

    public init(library: any ScanLibrary, today: Today, calendar: Calendar) {
        self.library = library
        self.today = today
        self.calendar = calendar
    }

    /// True when no scan is visible: Home shows descriptions and no views.
    public var isEmpty: Bool { shelf.visible.isEmpty }

    public var rows: [HomeRow] {
        let shelf = shelf
        let showsCounts = !shelf.visible.isEmpty
        return BuiltInCollection.allCases.map { collection in
            HomeRow(
                collection: collection,
                name: CollectionText.name(collection),
                detail: showsCounts
                    ? .count(shelf.count(in: collection))
                    : .subtitle(
                        CollectionText.description(collection) + " · "
                            + CollectionText.lifespanShort(collection.lifespan))
            )
        }
    }

    public var viewRows: [HomeViewRow] {
        let shelf = shelf
        guard !shelf.visible.isEmpty else { return [] }
        return [
            HomeViewRow(kind: .recent, name: CollectionText.recent, count: nil),
            HomeViewRow(kind: .all, name: CollectionText.allScans, count: shelf.visible.count),
        ]
    }

    private var shelf: LibraryShelf {
        LibraryShelf(scans: library.scans, today: today.day, calendar: calendar)
    }
}
