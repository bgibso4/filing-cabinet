import Core
import Foundation
import Library
import Observation

/// Keeps iPhone search in step with the library (A10): while `run()` runs, every scan in the library, not Trash, is
/// indexed by its title, "Receipts · 3 pages" and page 1's thumbnail. A change indexes what changed and removes what
/// left. The app runs one once launch has purged Trash, so a purged scan is never indexed.
@MainActor
public final class SpotlightSync {
    /// Bump to rebuild every phone's index once: a new item shape or a fix to an old one.
    package static let version = 1
    /// Thumbnails read and sent per index call, so a first build of a large library never holds them all at once.
    private static let batchSize = 100

    private let library: any ScanLibrary
    private let today: Today
    private let index: any SpotlightIndexing
    private let thumbnails: @Sendable (ScanID) async -> Data?
    private let preferences: AppPreferences
    /// What the index holds, without thumbnails (page 1 never changes, so they don't need comparing). A failed call
    /// leaves its scans as they were here, so the next pass tries them again.
    private var indexed: [ScanID: SpotlightItem] = [:]

    /// `thumbnails` gives page 1's cached JPEG, or nil.
    public init(
        library: any ScanLibrary,
        today: Today,
        index: any SpotlightIndexing,
        thumbnails: @escaping @Sendable (ScanID) async -> Data?,
        preferences: AppPreferences
    ) {
        self.library = library
        self.today = today
        self.index = index
        self.thumbnails = thumbnails
        self.preferences = preferences
    }

    /// Syncs now and after every change, one pass at a time, until cancelled.
    public func run() async {
        // Read for their changes only: each pass reads the library and the day as they are then.
        let changes = Observations { _ = (self.library.scans, self.library.lifespans, self.today.day) }
        for await _ in changes {
            await sync()
        }
    }

    private func sync() async {
        let rebuilding = preferences.spotlightVersion < Self.version
        if rebuilding {
            do {
                try await index.removeAll()
                indexed = [:]
            } catch {
                log("Clearing", error)
                return
            }
        }
        let wanted = wantedItems()
        let changed = wanted.values.filter { indexed[$0.id] != $0 }
        let gone = indexed.keys.filter { wanted[$0] == nil }
        var succeeded = true
        for start in stride(from: 0, to: changed.count, by: Self.batchSize) {
            let batch = changed[start..<min(start + Self.batchSize, changed.count)]
            succeeded = await add(Array(batch)) && succeeded
        }
        if !gone.isEmpty {
            do {
                try await index.remove(gone)
                for id in gone { indexed[id] = nil }
            } catch {
                log("Removing", error)
                succeeded = false
            }
        }
        if rebuilding && succeeded { preferences.spotlightVersion = Self.version }
    }

    /// Indexes the items with their thumbnails and records them; false when the call failed.
    private func add(_ items: [SpotlightItem]) async -> Bool {
        var full: [SpotlightItem] = []
        for item in items {
            full.append(
                SpotlightItem(
                    id: item.id,
                    title: item.title,
                    detail: item.detail,
                    thumbnail: await thumbnails(item.id),
                    expires: item.expires))
        }
        do {
            try await index.index(full)
        } catch {
            log("Indexing", error)
            return false
        }
        for item in items { indexed[item.id] = item }
        return true
    }

    /// Every scan in the library today, not Trash, without its thumbnail.
    private func wantedItems() -> [ScanID: SpotlightItem] {
        let calendar = today.calendar
        let shelf = LibraryShelf(
            scans: library.scans, lifespans: library.lifespans, today: today.day, calendar: calendar)
        var items: [ScanID: SpotlightItem] = [:]
        for scan in shelf.visible {
            let lastDay = scan.lastDay(lifespans: shelf.lifespans, in: calendar)
            let entry = Lifecycle.entryDay(lastDay: lastDay, trashedDay: scan.trashedDay, in: calendar)
            items[scan.id] = SpotlightItem(
                id: scan.id,
                title: scan.title,
                detail: Self.detail(scan),
                thumbnail: nil,
                expires: entry?.date(in: calendar))
        }
        return items
    }

    /// "Receipts · 3 pages", "Notes · 1 page".
    package static func detail(_ scan: ScanSummary) -> String {
        let pages = String(localized: "\(scan.pageCount) pages", bundle: #bundle)
        return String(localized: "\(CollectionText.name(scan.collection)) · \(pages)", bundle: #bundle)
    }

    private func log(_ action: String, _ error: any Error) {
        ScreenModelsLog.logger.error(
            "\(action, privacy: .public) Spotlight failed: \(error.localizedDescription, privacy: .private)")
    }
}
