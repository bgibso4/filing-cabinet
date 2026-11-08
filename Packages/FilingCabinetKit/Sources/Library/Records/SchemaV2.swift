import SwiftData

/// The current schema: plan 1's scans plus Trash and per-collection lifespans.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] { [ScanRecord.self, CollectionRecord.self] }
}

/// The current schema's records, by their plain names.
typealias ScanRecord = SchemaV2.ScanRecord
typealias CollectionRecord = SchemaV2.CollectionRecord
