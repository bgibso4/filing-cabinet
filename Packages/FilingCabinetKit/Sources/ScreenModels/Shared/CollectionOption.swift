import Core

/// One row of the collection menu Review and Details share: "Receipts", "3 months".
package struct CollectionOption {
    package let collection: BuiltInCollection
    package let name: String
    /// "Kept forever", "3 months", "1 week".
    package let lifespan: String

    /// Every collection, in order, with its lifespan under `lifespans`.
    static func all(lifespans: CollectionLifespans) -> [Self] {
        BuiltInCollection.allCases.map {
            Self(
                collection: $0,
                name: CollectionText.name($0),
                lifespan: CollectionText.lifespanShort(lifespans[$0]))
        }
    }
}
