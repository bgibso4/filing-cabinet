import SwiftData

/// The current schema: plan 4's scans plus the model's hidden search words (M1).
enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] { [ScanRecord.self, CollectionRecord.self] }
}

/// The current schema's records, by their plain names.
typealias ScanRecord = SchemaV4.ScanRecord
typealias CollectionRecord = SchemaV4.CollectionRecord
