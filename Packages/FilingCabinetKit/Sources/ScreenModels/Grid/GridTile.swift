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

    package init(
        id: ScanID,
        title: String,
        collectionName: String,
        timeLeft: String,
        isSoon: Bool,
        dot: BuiltInCollection?,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.collectionName = collectionName
        self.timeLeft = timeLeft
        self.isSoon = isSoon
        self.dot = dot
        self.isFavorite = isFavorite
    }

    /// What VoiceOver reads for the whole tile: "Corner Market, Receipts, 2 days left", then ", favorite" (M13).
    package var accessibilityLabel: String {
        let label = String(localized: "\(title), \(collectionName), \(timeLeft)", bundle: #bundle)
        return isFavorite ? String(localized: "\(label), favorite", bundle: #bundle) : label
    }
}
