import Core
import Foundation

/// The copy of Move to Trash, from the viewer (06-04, M19) and from a grid's selection (#68).
package enum MoveToTrashText {
    /// The confirmation's message, naming the scans as their collection does when they share one (M5): "This receipt
    /// moves to Trash. You can restore it for 30 days." or "These 2 receipts move to Trash. You can restore them for 30
    /// days." `collection` nil (mixed, or unknown) calls them scans.
    package static func message(count: Int, collection: BuiltInCollection?) -> String {
        let noun = collection.map { CollectionText.noun($0, count: count) } ?? CollectionText.scansNoun(count: count)
        guard count != 1 else {
            return String(
                localized: "This \(noun) moves to Trash. You can restore it for \(Lifecycle.trashDays) days.",
                bundle: #bundle)
        }
        return String(
            localized: "These \(count) \(noun) move to Trash. You can restore them for \(Lifecycle.trashDays) days.",
            bundle: #bundle)
    }

    /// What VoiceOver hears once they have moved (M19): "Moved to Trash", or "Moved 2 scans to Trash".
    package static func announcement(count: Int) -> String {
        count == 1
            ? String(localized: "Moved to Trash", bundle: #bundle)
            : String(localized: "Moved \(count) scans to Trash", bundle: #bundle)
    }
}
