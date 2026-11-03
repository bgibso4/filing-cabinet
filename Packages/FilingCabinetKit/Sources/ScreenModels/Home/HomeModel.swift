import Core
import Foundation
import Observation

/// What Home shows on first launch: the five built-in collections with their lifespans.
@Observable
public final class HomeModel {
    public let rows: [HomeRow]

    public init() {
        rows = BuiltInCollection.allCases.map { collection in
            HomeRow(
                collection: collection,
                name: CollectionText.name(collection),
                subtitle: CollectionText.description(collection) + " · "
                    + CollectionText.lifespanShort(collection.lifespan)
            )
        }
    }
}
