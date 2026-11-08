import Foundation
import SwiftData

/// The schema plan 1 shipped, frozen: stores written before versioning migrate from here. Never edit it;
/// a schema change is a new version plus a stage in `LibraryMigrationPlan`.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] { [ScanRecord.self] }

    /// Plan 1's scan record: the stored properties and defaults exactly as shipped.
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

        init() {}
    }
}
