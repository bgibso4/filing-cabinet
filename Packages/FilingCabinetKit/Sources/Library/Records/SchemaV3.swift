import Foundation
import SwiftData

/// Plan 4's schema, frozen: plan 2's scans plus favourites. Never edit it; a schema change is a new version plus a
/// stage in `LibraryMigrationPlan`.
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] { [ScanRecord.self, CollectionRecord.self] }

    /// Plan 4's scan record: the stored properties and defaults exactly as shipped.
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
        var favoriteOrder: Int?

        init() {}
    }

    /// Plan 4's collection record, as shipped.
    @Model
    final class CollectionRecord {
        var collectionKey: String = ""
        var lifespanKey: String = ""

        init() {}
    }
}
