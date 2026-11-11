import SwiftData

/// The current schema: plan 2's scans plus favourites (M1).
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] { [ScanRecord.self, CollectionRecord.self] }
}

/// The current schema's records, by their plain names.
typealias ScanRecord = SchemaV3.ScanRecord
typealias CollectionRecord = SchemaV3.CollectionRecord
