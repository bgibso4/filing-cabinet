import Core
import CoreGraphics
import Foundation
import Library

/// Fills a library with synthetic scans for `-SeedScans`, `-SeedTrash` and tests.
public enum LibrarySeed {
    /// Small pages, so seeding a dozen scans at launch stays quick.
    private static let pageSize = CGSize(width: 620, height: 877)
    private static let titleSize: CGFloat = 48

    /// Documents' scans have this many pages, so a seeded library has scans to swipe through.
    private static let documentPageCount = 3

    /// Saves `count` scans, cycling through the five collections in display order: one page each, more in Documents.
    /// Scan `n` (from 0) is dated `n` days before `clock.now()`, so the newest is first. The first `favorites` are
    /// favourites, in seed order.
    @MainActor
    public static func seed(_ store: ScanStore, count: Int, favorites: Int = 0, clock: AppClock) async throws {
        let ids = try await save(store, count: count, titled: "Sample scan", clock: clock)
        try store.setFavorite(true, for: Array(ids.prefix(favorites)))
    }

    /// Saves `count` scans as `seed` does, then moves scan `n` to Trash on the day it was scanned, `n` days before
    /// today, as if moved there by hand. Their titles differ from `seed`'s, so both can seed one library.
    @MainActor
    public static func seedTrash(_ store: ScanStore, count: Int, clock: AppClock) async throws {
        let ids = try await save(store, count: count, titled: "Trashed scan", clock: clock)
        for (index, id) in ids.enumerated() {
            try store.moveToTrash([id], on: clock.today.adding(days: -index, in: clock.calendar))
        }
    }

    /// The saved scans' IDs, in order: "<title> 1" first.
    @MainActor
    private static func save(_ store: ScanStore, count: Int, titled prefix: String, clock: AppClock) async throws
        -> [ScanID]
    {
        let now = clock.now()
        let collections = BuiltInCollection.allCases
        var ids: [ScanID] = []
        for index in 0..<count {
            let title = "\(prefix) \(index + 1)"
            let collection = collections[index % collections.count]
            let pages = (1...(collection == .documents ? documentPageCount : 1)).map { number in
                SyntheticPages.page(lines: [(title, titleSize), ("Page \(number)", titleSize)], size: pageSize)
            }
            let scannedAt = clock.calendar.date(byAdding: .day, value: -index, to: now) ?? now
            let id = ScanID()
            try await store.save(
                ScanDraft(
                    id: id,
                    title: title,
                    collection: collection,
                    scannedAt: scannedAt,
                    expiryOverride: nil,
                    pages: pages,
                    searchText: title
                ))
            ids.append(id)
        }
        return ids
    }
}
