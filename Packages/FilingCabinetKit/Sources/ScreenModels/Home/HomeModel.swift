import Core
import Foundation
import Library
import Observation

/// What Home shows: the collections with their counts, and the Recent and All Scans views. With no visible scan
/// it shows the first-launch rows instead (M14). Expired scans are not counted (M5); everything is read from the
/// library and from `Today`, so the numbers move when either does, except while held: under the capture layer Home
/// keeps showing the library as it was, so a save lands on Home after the layer slides away (P5).
@Observable
public final class HomeModel {
    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    /// The scans Home shows while held; nil when it follows the library.
    private var heldScans: [ScanSummary]?
    /// Per collection, how many times a release found its count higher: each row's pop trigger.
    private var pulses: [BuiltInCollection: Int] = [:]

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
                            + CollectionText.lifespanShort(shelf.lifespans[collection])),
                pulse: pulses[collection, default: 0]
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

    /// Keeps showing the library as it is now until `release`. The root holds Home while the capture layer is up.
    package func hold() {
        // A second hold keeps the first snapshot, so a save made under the layer still counts as new on release.
        guard heldScans == nil else { return }
        heldScans = library.scans
    }

    /// Catches up with the library, and pulses each collection whose count went up while Home was held. Without a
    /// hold it does nothing. It compares net counts: a save and an expiry in the same collection while held cancel
    /// out and pulse nothing.
    package func release() {
        guard let heldScans else { return }
        let before = LibraryShelf(scans: heldScans, lifespans: library.lifespans, today: today.day, calendar: calendar)
        self.heldScans = nil
        let after = shelf
        for collection in BuiltInCollection.allCases
        where after.count(in: collection) > before.count(in: collection) {
            pulses[collection, default: 0] += 1
        }
    }

    private var shelf: LibraryShelf {
        LibraryShelf(
            scans: heldScans ?? library.scans, lifespans: library.lifespans, today: today.day, calendar: calendar)
    }
}
