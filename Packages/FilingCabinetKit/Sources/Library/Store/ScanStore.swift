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
public final class ScanStore: ScanLibrary {
    /// Every scan, newest `scannedAt` first.
    public private(set) var scans: [ScanSummary] = []
    /// How long each collection keeps its scans: the defaults, changed by the stored `CollectionRecord`s.
    public private(set) var lifespans: CollectionLifespans = .defaults
    public private(set) var searchTextRevision = 0

    /// Held so the main context keeps working: a context does not keep its container alive.
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let files: PageFileStore
    /// Today, for Trash days. Internal, like the helpers the favourites extension uses.
    @ObservationIgnored let clock: AppClock
    @ObservationIgnored private let persist: (ModelContext) throws -> Void
    /// Every fetch of scan records goes through here.
    @ObservationIgnored let fetch: (ModelContext, FetchDescriptor<ScanRecord>) throws -> [ScanRecord]
    /// Scans whose files may be on disk before their record is: orphan cleanup must leave them alone.
    @ObservationIgnored private var inFlight: Set<ScanID> = []

    /// `persist` defaults to `context.save()`; tests inject a failure.
    public convenience init(
        container: ModelContainer,
        files: PageFileStore,
        clock: AppClock,
        persist: ((ModelContext) throws -> Void)? = nil
    ) {
        self.init(container: container, files: files, clock: clock, persist: persist, fetch: nil)
    }

    /// `fetch` defaults to `context.fetch(_:)`; tests count fetches.
    init(
        container: ModelContainer,
        files: PageFileStore,
        clock: AppClock,
        persist: ((ModelContext) throws -> Void)?,
        fetch: ((ModelContext, FetchDescriptor<ScanRecord>) throws -> [ScanRecord])?
    ) {
        self.container = container
        // Every write is persisted explicitly, so a failed save can be rolled back before autosave sees it.
        container.mainContext.autosaveEnabled = false
        self.files = files
        self.clock = clock
        self.persist = persist ?? { try $0.save() }
        self.fetch = fetch ?? { try $0.fetch($1) }
        reloadScans()
        reloadLifespans()
    }

    /// The SwiftData container for the library, migrating an older store to the current schema. A nil
    /// `storeURL` keeps the store in memory.
    public static func makeContainer(storeURL: URL?) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration =
            if let storeURL {
                ModelConfiguration(schema: schema, url: storeURL)
            } else {
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            }
        return try ModelContainer(
            for: schema, migrationPlan: LibraryMigrationPlan.self, configurations: configuration)
    }

    public func save(_ draft: ScanDraft) async throws(LibraryError) {
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

    public func updateSearchText(_ text: String, for id: ScanID) {
        let scanID = id.uuid.uuidString
        guard let record = record(for: id) else {
            LibraryLog.logger.error("No record for scan \(scanID, privacy: .public) to add search text to")
            return
        }
        record.searchText = text
        do {
            try persist(context)
            searchTextRevision += 1
        } catch {
            LibraryLog.logger.error(
                "Saving search text for scan \(scanID, privacy: .public) failed: \(error.localizedDescription, privacy: .private)"
            )
            context.rollback()
        }
    }

    public func rename(_ id: ScanID, to title: String) throws(LibraryError) {
        LibraryLog.logger.info("Renaming scan \(id.uuid.uuidString, privacy: .public): \(title, privacy: .private)")
        try edit([id]) { $0.title = title }
    }

    public func move(_ id: ScanID, to collection: BuiltInCollection) throws(LibraryError) {
        LibraryLog.logger.info(
            "Moving scan \(id.uuid.uuidString, privacy: .public) to \(collection.rawValue, privacy: .public)")
        try edit([id]) { record in
            stampTrashedDay(on: record) { $0.collection = collection }
            record.collectionKey = collection.rawValue
        }
    }

    public func setExpiry(_ override: ExpiryOverride?, for id: ScanID) throws(LibraryError) {
        LibraryLog.logger.info("Setting the expiry of scan \(id.uuid.uuidString, privacy: .public)")
        try edit([id]) { record in
            stampTrashedDay(on: record) { $0.expiryOverride = override }
            record.expiryOverride = override
        }
    }

    public func moveToTrash(_ ids: [ScanID]) throws(LibraryError) {
        try moveToTrash(ids, on: clock.today)
    }

    /// Moves the scans to Trash as if on `day`: `-SeedTrash` staggers them, so Trash shows a spread of days left.
    package func moveToTrash(_ ids: [ScanID], on day: CalendarDay) throws(LibraryError) {
        LibraryLog.logger.info(
            "Moving \(ids.count, privacy: .public) scans to Trash: \(Self.list(ids), privacy: .public)")
        try edit(ids) { $0.trashedDay = day.storageValue }
    }

    public func restore(_ ids: [ScanID]) throws(LibraryError) {
        LibraryLog.logger.info("Restoring \(ids.count, privacy: .public) scans: \(Self.list(ids), privacy: .public)")
        try edit(ids) { record in
            record.trashedDay = nil
            record.expiryOverride = .lifespan(.forever)
        }
    }

    public func deleteNow(_ ids: [ScanID]) async throws(LibraryError) {
        LibraryLog.logger.info("Deleting \(ids.count, privacy: .public) scans: \(Self.list(ids), privacy: .public)")
        try await delete(try records(for: ids))
    }

    /// Removes page folders that have no record and are not being saved right now: what a kill between
    /// writing files and inserting the record leaves behind. Anything it cannot confirm is kept.
    public func removeOrphanedFiles() async {
        let stored = await files.storedScanIDs()
        // Read once, after the listing: a listed folder's scan is then either recorded or still saving. A save
        // in flight now may finish during the removals, so it is kept by this snapshot, not a later check.
        guard let recorded = recordedScanIDs() else { return }
        let keep = recorded.union(inFlight.map(\.uuid))
        var removed = 0
        for id in stored where !keep.contains(id.uuid) {
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

    /// Changes each scan's record, then persists: all or nothing.
    func edit(_ ids: [ScanID], _ change: (ScanRecord) -> Void) throws(LibraryError) {
        try records(for: ids).forEach(change)
        try persistEdit()
    }

    /// Stores the Trash day the change brings (M1); call it before applying the change to the record.
    private func stampTrashedDay(on record: ScanRecord, _ change: (inout ScanSummary) -> Void) {
        guard let scan = record.summary else { return }
        var changed = scan
        change(&changed)
        let trashedDay = scan.trashedDay(
            afterLastDayChangesTo: changed.lastDay(lifespans: lifespans, in: clock.calendar),
            lifespans: lifespans,
            today: clock.today,
            in: clock.calendar)
        record.trashedDay = trashedDay?.storageValue
    }

    /// Removes the records, then the files (M11).
    private func delete(_ records: [ScanRecord]) async throws(LibraryError) {
        let deleted = records.map { ScanID(uuid: $0.scanID) }
        records.forEach(context.delete)
        try persistEdit()
        for id in deleted {
            await files.remove(id)
        }
    }

    /// Persists the pending edits and reloads `scans`; on failure discards them and throws `.writeFailed`.
    private func persistEdit() throws(LibraryError) {
        do {
            try persist(context)
        } catch {
            LibraryLog.logger.error("Saving an edit failed: \(error.localizedDescription, privacy: .private)")
            context.rollback()
            throw .writeFailed
        }
        reloadScans()
    }

    /// The records of these scans, in one fetch. Scans with no record are logged and left out; a failed fetch
    /// throws `.writeFailed`, since the edit cannot happen.
    private func records(for ids: [ScanID]) throws(LibraryError) -> [ScanRecord] {
        let uuids = ids.map(\.uuid)
        let found = try records(FetchDescriptor(predicate: #Predicate { uuids.contains($0.scanID) }))
        if found.count < ids.count {
            LibraryLog.logger.error(
                "\(ids.count - found.count, privacy: .public) of \(ids.count, privacy: .public) scans have no record")
        }
        return found
    }

    /// One fetch of scan records; a failure throws `.writeFailed`, since the edit cannot happen.
    private func records(_ descriptor: FetchDescriptor<ScanRecord>) throws(LibraryError) -> [ScanRecord] {
        do {
            return try fetch(context, descriptor)
        } catch {
            LibraryLog.logger.error("Fetching scans failed: \(error.localizedDescription, privacy: .private)")
            throw .writeFailed
        }
    }

    static func list(_ ids: [ScanID]) -> String {
        ids.map(\.uuid.uuidString).joined(separator: ", ")
    }

    /// The one context every SwiftData read and write goes through.
    var context: ModelContext { container.mainContext }

    /// Every recorded scan, in one fetch; nil when the fetch fails.
    private func recordedScanIDs() -> Set<UUID>? {
        var descriptor = FetchDescriptor<ScanRecord>()
        descriptor.propertiesToFetch = [\.scanID]
        do {
            return Set(try fetch(context, descriptor).map(\.scanID))
        } catch {
            LibraryLog.logger.error("Listing recorded scans failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    func record(for id: ScanID) -> ScanRecord? {
        let uuid = id.uuid
        var descriptor = FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.scanID == uuid })
        descriptor.fetchLimit = 1
        do {
            return try fetch(context, descriptor).first
        } catch {
            LibraryLog.logger.error(
                "Fetching scan \(uuid.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .private)"
            )
            return nil
        }
    }

    /// Loads `lifespans` from the stored `CollectionRecord`s.
    private func reloadLifespans() {
        do {
            lifespans = try CollectionRecord.lifespans(in: context)
        } catch {
            LibraryLog.logger.error("Loading lifespans failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func reloadScans() {
        let descriptor = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.scannedAt, order: .reverse)])
        do {
            scans = try fetch(context, descriptor).compactMap(\.summary)
        } catch {
            LibraryLog.logger.error("Loading scans failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}

/// Lifespans, Trash and the purge: the edits that follow from where scans are (M1, M11).
extension ScanStore {
    public func emptyTrash() async throws(LibraryError) -> Int {
        let trashed = try records { place in
            if case .library = place { return false }
            return true
        }
        LibraryLog.logger.info("Emptying Trash: \(trashed.count, privacy: .public) scans")
        try await delete(trashed)
        return trashed.count
    }

    public func setLifespan(_ lifespan: Lifespan, for collection: BuiltInCollection) throws(LibraryError) {
        let signpost = LibraryLog.signposter.beginInterval(
            "Lifespan change", id: LibraryLog.signposter.makeSignpostID())
        defer { LibraryLog.signposter.endInterval("Lifespan change", signpost) }
        LibraryLog.logger.info(
            "Keeping \(collection.rawValue, privacy: .public) for \(lifespan.rawValue, privacy: .public)")
        let records = try records(FetchDescriptor())
        do {
            try CollectionRecord.set(lifespan, for: collection, in: context)
        } catch {
            LibraryLog.logger.error("Storing a lifespan failed: \(error.localizedDescription, privacy: .private)")
            context.rollback()
            throw .writeFailed
        }
        let changed = lifespans.setting(lifespan, for: collection)
        for record in records {
            guard let scan = record.summary else { continue }
            let trashedDay = scan.trashedDay(
                afterLifespansChangeTo: changed, from: lifespans, today: clock.today, in: clock.calendar)
            record.trashedDay = trashedDay?.storageValue
        }
        try persistEdit()
        reloadLifespans()
    }

    public func scansExpiring(ifLifespan lifespan: Lifespan, for collection: BuiltInCollection) -> Int {
        let changed = lifespans.setting(lifespan, for: collection)
        return scans.count {
            $0.entersTrash(ifLifespansChangeTo: changed, from: lifespans, today: clock.today, in: clock.calendar)
        }
    }

    /// Deletes every scan past its 30 days in Trash, as `deleteNow` does, and returns how many. Run after
    /// `removeOrphanedFiles()`: an interrupted purge leaves only orphaned files. A failure is logged and
    /// deletes nothing.
    public func purgeTrash() async -> Int {
        let signpost = LibraryLog.signposter.beginInterval("Purge", id: LibraryLog.signposter.makeSignpostID())
        defer { LibraryLog.signposter.endInterval("Purge", signpost) }
        do {
            let gone = try records { $0 == .gone }
            guard !gone.isEmpty else { return 0 }
            try await delete(gone)
            LibraryLog.logger.info("Purged \(gone.count, privacy: .public) scans from Trash")
            return gone.count
        } catch {
            LibraryLog.logger.error("Purging Trash failed")
            return 0
        }
    }

    /// The records of scans whose place today matches, in one fetch. Records naming no collection are skipped.
    private func records(where matches: (ScanPlace) -> Bool) throws(LibraryError) -> [ScanRecord] {
        try records(FetchDescriptor()).filter { record in
            record.summary.map { matches($0.place(lifespans: lifespans, today: clock.today, in: clock.calendar)) }
                ?? false
        }
    }
}
