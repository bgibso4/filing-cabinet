/// How long each collection keeps its scans. The single source of a collection's lifespan: nothing else
/// reads `BuiltInCollection.defaultLifespan`.
public struct CollectionLifespans: Sendable, Hashable {
    private let byCollection: [BuiltInCollection: Lifespan]

    /// The requirements' defaults.
    package static let defaults = Self(
        byCollection: Dictionary(uniqueKeysWithValues: BuiltInCollection.allCases.map { ($0, $0.defaultLifespan) }))

    package subscript(_ collection: BuiltInCollection) -> Lifespan {
        byCollection[collection] ?? collection.defaultLifespan
    }

    package func setting(_ lifespan: Lifespan, for collection: BuiltInCollection) -> Self {
        var updated = byCollection
        updated[collection] = lifespan
        return Self(byCollection: updated)
    }
}
