import Core
import Foundation
import SwiftData

extension SchemaV4 {
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

extension CollectionRecord {
    /// The defaults, with each stored choice applied. A record naming no collection or lifespan is ignored.
    static func lifespans(in context: ModelContext) throws -> CollectionLifespans {
        try context.fetch(FetchDescriptor<CollectionRecord>()).reduce(.defaults) { lifespans, record in
            guard let collection = BuiltInCollection(rawValue: record.collectionKey),
                let lifespan = Lifespan(rawValue: record.lifespanKey)
            else { return lifespans }
            return lifespans.setting(lifespan, for: collection)
        }
    }

    /// Records the collection's lifespan in `context`, unsaved: updates its record, or inserts one.
    static func set(_ lifespan: Lifespan, for collection: BuiltInCollection, in context: ModelContext) throws {
        let key = collection.rawValue
        let stored = try context.fetch(
            FetchDescriptor<CollectionRecord>(predicate: #Predicate { $0.collectionKey == key }))
        guard stored.isEmpty else {
            stored.forEach { $0.lifespanKey = lifespan.rawValue }
            return
        }
        let record = CollectionRecord()
        record.collectionKey = key
        record.lifespanKey = lifespan.rawValue
        context.insert(record)
    }
}
