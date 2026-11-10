import Core
import Foundation

/// One scan in a grid.
package struct GridTile: Identifiable, Equatable {
    package let id: ScanID
    package let title: String
    private let collectionName: String
    package let timeLeft: String
    package let isSoon: Bool
    /// The collection's dot, in the grids that mix collections (05-04); nil in a single collection's grid.
    package let dot: BuiltInCollection?
    /// Marked with a heart (M13).
    package let isFavorite: Bool
    /// Taken out of Favorites while Favorites is on screen: the tile stays, with an empty heart, until the screen goes
    /// (M9).
    package let isUnfavorited: Bool

    package init(
        id: ScanID,
        title: String,
        collectionName: String,
        timeLeft: String,
        isSoon: Bool,
        dot: BuiltInCollection?,
        isFavorite: Bool = false,
        isUnfavorited: Bool = false
    ) {
        self.id = id
        self.title = title
        self.collectionName = collectionName
        self.timeLeft = timeLeft
        self.isSoon = isSoon
        self.dot = dot
        self.isFavorite = isFavorite
        self.isUnfavorited = isUnfavorited
    }

    /// What VoiceOver reads for the whole tile: "Corner Market, Receipts, 2 days left", then ", favorite" (M13), or
    /// ", not a favorite" for a tile kept in Favorites (M9, Collection.dc.html's `unfav` state).
    package var accessibilityLabel: String {
        let label = String(localized: "\(title), \(collectionName), \(timeLeft)", bundle: #bundle)
        if isFavorite { return String(localized: "\(label), favorite", bundle: #bundle) }
        if isUnfavorited { return String(localized: "\(label), not a favorite", bundle: #bundle) }
        return label
    }
}
