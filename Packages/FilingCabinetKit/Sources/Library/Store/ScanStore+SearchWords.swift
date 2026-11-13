import Core
import SwiftData

/// The model's hidden search words and which scans still need them (M1, M9). Never shown, never logged.
extension ScanStore {
    public func updateSearchWords(_ words: [String], version: Int, for id: ScanID) {
        let scanID = id.uuid.uuidString
        guard let record = record(for: id) else {
            LibraryLog.logger.error("No record for scan \(scanID, privacy: .public) to add search words to")
            return
        }
        record.searchWordList = words
        record.searchWordsVersion = version
        do {
            try persist(context)
            searchTextRevision += 1
        } catch {
            LibraryLog.logger.error(
                "Saving search words for scan \(scanID, privacy: .public) failed: \(error.localizedDescription, privacy: .private)"
            )
            context.rollback()
        }
    }

    public func searchWords() -> [ScanID: [String]] {
        var descriptor = FetchDescriptor<ScanRecord>()
        descriptor.propertiesToFetch = [\.scanID, \.searchWords]
        do {
            let records = try fetch(context, descriptor)
            return Dictionary(records.map { (ScanID(uuid: $0.scanID), $0.searchWordList) }) { first, _ in first }
        } catch {
            LibraryLog.logger.error("Reading search words failed: \(error.localizedDescription, privacy: .private)")
            return [:]
        }
    }

    public func scansNeedingWords(version: Int) -> [ScanID] {
        var descriptor = FetchDescriptor<ScanRecord>()
        descriptor.propertiesToFetch = [\.scanID, \.searchWordsVersion]
        let versions: [ScanID: Int]
        do {
            versions = Dictionary(
                try fetch(context, descriptor).compactMap { record in
                    record.searchWordsVersion.map { (ScanID(uuid: record.scanID), $0) }
                }
            ) { first, _ in first }
        } catch {
            LibraryLog.logger.error(
                "Reading search word versions failed: \(error.localizedDescription, privacy: .private)")
            return []
        }
        return scans.filter { scan in
            guard case .library = scan.place(lifespans: lifespans, today: clock.today, in: clock.calendar) else {
                return false
            }
            return versions[scan.id].map { $0 < version } ?? true
        }.map(\.id)
    }
}
