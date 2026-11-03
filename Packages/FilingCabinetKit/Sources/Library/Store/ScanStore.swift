import Core
import Foundation
import Observation
import SwiftData

/// The library on disk: SwiftData records plus page files, saved all or nothing (M21).
///
/// Every SwiftData write goes through the main context and records never leave the main actor; file work
/// runs on `PageFileStore`'s `@concurrent` methods. A scan's files are written before its record, so a kill
/// in between leaves only orphaned folders, which `removeOrphanedFiles()` clears at the next launch.
@MainActor
@Observable
package final class ScanStore: ScanLibrary {
    /// Every scan, newest `scannedAt` first.
    package private(set) var scans: [ScanSummary] = []

    /// Held so the main context keeps working: a context does not keep its container alive.
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let files: PageFileStore
    @ObservationIgnored private let persist: (ModelContext) throws -> Void
    /// Scans whose files may be on disk before their record is: orphan cleanup must leave them alone.
    @ObservationIgnored private var inFlight: Set<ScanID> = []

    /// `persist` defaults to `context.save()`; tests inject a failure.
    package init(container: ModelContainer, files: PageFileStore, persist: ((ModelContext) throws -> Void)? = nil) {
        self.container = container
        // Every write is persisted explicitly, so a failed save can be rolled back before autosave sees it.
        container.mainContext.autosaveEnabled = false
        self.files = files
        self.persist = persist ?? { try $0.save() }
        reloadScans()
    }

    /// The SwiftData container for the library. A nil `storeURL` keeps the store in memory.
    package static func makeContainer(storeURL: URL?) throws -> ModelContainer {
        let schema = Schema([ScanRecord.self])
        let configuration =
            if let storeURL {
                ModelConfiguration(schema: schema, url: storeURL)
            } else {
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    package func save(_ draft: ScanDraft) async throws(LibraryError) {
        let signpost = LibraryLog.signposter.beginInterval("Scan to saved", id: LibraryLog.signposter.makeSignpostID())
        defer { LibraryLog.signposter.endInterval("Scan to saved", signpost) }
        let scanID = draft.id.uuid.uuidString
        inFlight.insert(draft.id)
        defer { inFlight.remove(draft.id) }
        LibraryLog.logger.info(
            "Saving scan \(scanID, privacy: .public), \(draft.pages.count, privacy: .public) pages: \(draft.title, privacy: .private)"
        )

        let fileNames = try await files.write(draft.pages, for: draft.id)

        let record = ScanRecord()
        record.scanID = draft.id.uuid
        record.title = draft.title
        record.collectionKey = draft.collection.rawValue
        record.scannedAt = draft.scannedAt
        record.expiryOverride = draft.expiryOverride
        record.pageFileNames = fileNames
        record.searchText = draft.searchText ?? ""
        context.insert(record)
        do {
            try persist(context)
        } catch {
            LibraryLog.logger.error(
                "Saving the record for scan \(scanID, privacy: .public) failed: \(error.localizedDescription, privacy: .private)"
            )
            context.rollback()
            await files.remove(draft.id)
            throw .writeFailed
        }
        LibraryLog.logger.info("Saved scan \(scanID, privacy: .public)")
        reloadScans()
    }

    package func updateSearchText(_ text: String, for id: ScanID) {
        let scanID = id.uuid.uuidString
        guard let record = record(for: id) else {
            LibraryLog.logger.error("No record for scan \(scanID, privacy: .public) to add search text to")
            return
        }
        record.searchText = text
        do {
            try persist(context)
        } catch {
            LibraryLog.logger.error(
                "Saving search text for scan \(scanID, privacy: .public) failed: \(error.localizedDescription, privacy: .private)"
            )
            context.rollback()
        }
    }

    /// Removes page folders that have no record and are not being saved right now: what a kill between
    /// writing files and inserting the record leaves behind. Anything it cannot confirm is kept.
    package func removeOrphanedFiles() async {
        let stored = await files.storedScanIDs()
        var removed = 0
        for id in stored {
            // Checked on the main actor right before each removal, after the listing and any earlier
            // removal, so a save that finished or started meanwhile is seen.
            guard !inFlight.contains(id), isOrphan(id) else { continue }
            await files.remove(id)
            removed += 1
        }
        LibraryLog.logger.info("Removed \(removed, privacy: .public) orphaned scan folders")
    }

    /// The scan's original page files in page order; empty when there is no such scan.
    package func pageFileURLs(for id: ScanID) -> [URL] {
        guard let record = record(for: id) else { return [] }
        return files.originalURLs(named: record.pageFileNames, for: id)
    }

    /// The one context every SwiftData read and write goes through.
    private var context: ModelContext { container.mainContext }

    private func isOrphan(_ id: ScanID) -> Bool {
        let uuid = id.uuid
        do {
            return try context.fetchCount(FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.scanID == uuid }))
                == 0
        } catch {
            LibraryLog.logger.error(
                "Checking scan \(uuid.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .private)"
            )
            return false
        }
    }

    private func record(for id: ScanID) -> ScanRecord? {
        let uuid = id.uuid
        var descriptor = FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.scanID == uuid })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            LibraryLog.logger.error(
                "Fetching scan \(uuid.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .private)"
            )
            return nil
        }
    }

    private func reloadScans() {
        let descriptor = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.scannedAt, order: .reverse)])
        do {
            scans = try context.fetch(descriptor).compactMap(\.summary)
        } catch {
            LibraryLog.logger.error("Loading scans failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
