import Core
import CoreGraphics
import Foundation
import Library

/// Fills a library with synthetic scans for `-SeedScans` and tests.
public enum LibrarySeed {
    /// Small pages, so seeding a dozen scans at launch stays quick.
    private static let pageSize = CGSize(width: 620, height: 877)
    private static let titleSize: CGFloat = 48

    /// Documents' scans have this many pages, so a seeded library has scans to swipe through.
    private static let documentPageCount = 3

    /// Saves `count` scans, cycling through the five collections in display order: one page each, more in Documents.
    /// Scan `n` (from 0) is dated `n` days before `clock.now()`, so the newest is first.
    @MainActor
    public static func seed(_ store: ScanStore, count: Int, clock: AppClock) async throws {
        let now = clock.now()
        let collections = BuiltInCollection.allCases
        for index in 0..<count {
            let title = "Sample scan \(index + 1)"
            let collection = collections[index % collections.count]
            let pages = (1...(collection == .documents ? documentPageCount : 1)).map { number in
                SyntheticPages.page(lines: [(title, titleSize), ("Page \(number)", titleSize)], size: pageSize)
            }
            let scannedAt = clock.calendar.date(byAdding: .day, value: -index, to: now) ?? now
            try await store.save(
                ScanDraft(
                    id: ScanID(),
                    title: title,
                    collection: collection,
                    scannedAt: scannedAt,
                    expiryOverride: nil,
                    pages: pages,
                    searchText: title
                ))
        }
    }
}
