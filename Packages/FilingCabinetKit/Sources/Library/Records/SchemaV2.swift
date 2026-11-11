import Foundation
import SwiftData

/// Plan 2's schema, frozen: plan 1's scans plus Trash and per-collection lifespans. Never edit it; a schema change is
/// a new version plus a stage in `LibraryMigrationPlan`.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] { [ScanRecord.self, CollectionRecord.self] }

    /// Plan 2's scan record: the stored properties and defaults exactly as shipped.
    @Model
    final class ScanRecord {
        var scanID: UUID = UUID()
        var title: String = ""
        var collectionKey: String = ""
        var scannedAt: Date = Date.distantPast
        var overrideLifespan: String?
        var overrideLastDay: Int?
        var pageFileNames: [String] = []
        var searchText: String = ""
        var trashedDay: Int?

        init() {}
    }

    /// Plan 2's collection record, as shipped.
    @Model
    final class CollectionRecord {
        var collectionKey: String = ""
        var lifespanKey: String = ""

        init() {}
    }
}
