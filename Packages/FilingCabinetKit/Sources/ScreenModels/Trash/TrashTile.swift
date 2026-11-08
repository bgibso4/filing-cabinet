import Core
import Foundation

/// One scan in Trash (09-01).
package struct TrashTile: Identifiable, Equatable {
    package let id: ScanID
    package let title: String
    package let collection: BuiltInCollection
    /// "2 days left".
    package let daysLeftText: String
    /// Orange: the last 7 days.
    package let isSoon: Bool

    /// What VoiceOver reads for the whole tile: "Coat check, Throwaways, 5 days left", as a grid's tile does.
    package var accessibilityLabel: String {
        String(localized: "\(title), \(CollectionText.name(collection)), \(daysLeftText)", bundle: #bundle)
    }
}
