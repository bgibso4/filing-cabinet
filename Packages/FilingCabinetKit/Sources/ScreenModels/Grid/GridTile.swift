import Core
import Foundation

/// One scan in a grid.
package struct GridTile: Identifiable, Equatable {
    package let id: ScanID
    package let title: String
    private let collectionName: String
    /// The second line: the scan's day and what is left of its life ("Nov 11 · 3 mo left").
    package let detail: String
    package let isSoon: Bool
    /// The collection's dot, in the grids that mix collections (05-04); nil in a single collection's grid.
    package let dot: BuiltInCollection?
    /// Marked with a heart (M13).
    package let isFavorite: Bool
    /// Taken out of Favorites while Favorites is on screen: the tile stays, with an empty heart, until the screen goes
    /// (M9).
    package let isUnfavorited: Bool
    /// VoiceOver's Move earlier and Move later: a favourite in Favorites, not while selecting, with a favourite before
    /// (or after) it.
    package let canMoveEarlier: Bool
    package let canMoveLater: Bool

    package init(
        id: ScanID,
        title: String,
        collectionName: String,
        detail: String,
        isSoon: Bool,
        dot: BuiltInCollection?,
        isFavorite: Bool = false,
        isUnfavorited: Bool = false,
        canMoveEarlier: Bool = false,
        canMoveLater: Bool = false
    ) {
        self.id = id
        self.title = title
        self.collectionName = collectionName
        self.detail = detail
        self.isSoon = isSoon
        self.dot = dot
        self.isFavorite = isFavorite
        self.isUnfavorited = isUnfavorited
        self.canMoveEarlier = canMoveEarlier
        self.canMoveLater = canMoveLater
    }

    /// What VoiceOver reads for the whole tile: "Corner Market, Receipts, Nov 11 · 2d left", then ", favorite" (M13), or
    /// ", not a favorite" for a tile kept in Favorites (M9, Collection.dc.html's `unfav` state).
    package var accessibilityLabel: String {
        let label = String(localized: "\(title), \(collectionName), \(detail)", bundle: #bundle)
        if isFavorite { return String(localized: "\(label), favorite", bundle: #bundle) }
        if isUnfavorited { return String(localized: "\(label), not a favorite", bundle: #bundle) }
        return label
    }
}
