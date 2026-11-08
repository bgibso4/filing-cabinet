import SwiftData

extension SchemaV2 {
    /// A collection's chosen lifespan. Plain values only, like `ScanRecord`.
    @Model
    final class CollectionRecord {
        /// A `BuiltInCollection.rawValue`.
        var collectionKey: String = ""
        /// A `Lifespan.rawValue`.
        var lifespanKey: String = ""

        init() {}
    }
}
