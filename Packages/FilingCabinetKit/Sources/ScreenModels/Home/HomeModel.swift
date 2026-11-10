import Core
import Foundation
import Library
import Observation

/// What Home shows: the first favourites, the collections with their counts, and the Recent and All Scans views. With
/// no visible scan it shows the first-launch rows instead (M14). Expired scans are not counted (M5); everything is read
/// from the library and from `Today`, so the numbers move when either does, except while held: under the capture layer
/// Home keeps showing the library as it was, so a save lands on Home after the layer slides away (P5).
@Observable
public final class HomeModel {
    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    private let cleanupBanner: CleanupBanner?
    /// The scans Home shows while held; nil when it follows the library.
    private var heldScans: [ScanSummary]?
    /// Per collection, how many times a release found its count higher: each row's pop trigger.
    private var pulses: [BuiltInCollection: Int] = [:]

    /// `banner` is the line after a cleanup; nil leaves Home without one.
    public init(library: any ScanLibrary, today: Today, calendar: Calendar, banner: CleanupBanner? = nil) {
        self.library = library
        self.today = today
        self.calendar = calendar
        cleanupBanner = banner
    }

    /// "4 scans moved to Trash" under the title (02-04), or nil.
    package var banner: String? { cleanupBanner?.text }

    /// The banner's View: Trash is about to show what it reported.
    package func clearBanner() {
        cleanupBanner?.clear()
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

    /// Recent, All Scans and Trash. With no visible scan only Trash shows, and only while something is in it (M7).
    public var viewRows: [HomeViewRow] {
        let shelf = shelf
        let trash = HomeViewRow(
            kind: .trash, name: CollectionText.trash, count: shelf.trash.isEmpty ? nil : shelf.trash.count)
        guard !shelf.visible.isEmpty else { return shelf.trash.isEmpty ? [] : [trash] }
        return [
            HomeViewRow(kind: .recent, name: CollectionText.recent, count: nil),
            HomeViewRow(kind: .all, name: CollectionText.allScans, count: shelf.visible.count),
            trash,
        ]
    }

    /// Favorites' first 10, in its own order, for the row under the title (02-01, M18); empty without favourites.
    package var favorites: [HomeFavorite] {
        shelf.favorites.prefix(Self.favoritesShown).map { HomeFavorite(id: $0.id, title: $0.title) }
    }

    /// "Favorites ›" opens the Favorites grid from 3 favourites; with 1 or 2 the header is plain (M18).
    package var favoritesOpensGrid: Bool { shelf.favorites.count >= Self.favoritesForLink }

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

    // M18: the row shows at most 10 favourites, and links to the grid from 3.
    private static let favoritesShown = 10
    private static let favoritesForLink = 3

    private var shelf: LibraryShelf {
        LibraryShelf(
            scans: heldScans ?? library.scans, lifespans: library.lifespans, today: today.day, calendar: calendar)
    }
}
