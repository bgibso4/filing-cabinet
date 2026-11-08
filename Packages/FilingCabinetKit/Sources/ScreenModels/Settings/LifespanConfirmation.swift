import Core
import Foundation

/// What shortening a lifespan asks before scans go to Trash (10-04).
package struct LifespanConfirmation: Equatable {
    package let title: String
    package let message: String
    /// "Change". Cancel is the system's.
    package let confirmTitle: String
    let lifespan: Lifespan

    /// `expiring` is how many scans the change sends to Trash now (at least one). `lifespan` is never Forever.
    init(collection: BuiltInCollection, lifespan: Lifespan, expiring count: Int) {
        let noun = CollectionText.noun(collection, count: count)
        let verb = count == 1 ? String(localized: "is", bundle: #bundle) : String(localized: "are", bundle: #bundle)
        let age = CollectionText.olderThan(lifespan) ?? ""
        title = CollectionText.keepTitle(collection, lifespan)
        message = String(
            localized:
                "\(count) \(noun) \(verb) older than \(age) and will go to Trash now. You can restore them for \(Lifecycle.trashDays) days.",
            bundle: #bundle)
        confirmTitle = String(localized: "Change", bundle: #bundle)
        self.lifespan = lifespan
    }
}
