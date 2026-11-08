import Core
import SwiftData

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
    package func purgeTrash() async -> Int {
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
