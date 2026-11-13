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

    /// The hidden words a seeded scan gets, by collection, so a UI test can search "ID" and find the wallet scans.
    private static let hiddenWords: [BuiltInCollection: [String]] = [
        .wallet: ["ID", "card", "licence"],
        .receipts: ["receipt", "purchase", "store"],
        .notes: ["note", "reminder", "memo"],
        .documents: ["document", "letter", "contract"],
        .throwaways: ["flyer", "coupon", "ticket"],
    ]

    /// Seeded words count as read by every prompt version, so the background pass never replaces them.
    private static let seededWordsVersion = Int.max

    /// Saves `count` scans, cycling through the five collections in display order: one page each, more in Documents.
    /// Each scan's search text is the lines its pages show ("Sample scan 1", "Page 1"), so Search finds real words.
    /// Scan `n` (from 0) is dated `n` days before `clock.now()`, so the newest is first. The first `favorites` are
    /// favourites, in seed order.
    /// Scan `n` (from 0) has the ID `scanID(at: n)`.
    @MainActor
    public static func seed(_ store: ScanStore, count: Int, favorites: Int = 0, clock: AppClock) async throws {
        let ids = try await save(store, count: count, titled: "Sample scan", clock: clock, id: scanID(at:))
        try store.setFavorite(true, for: Array(ids.prefix(favorites)))
    }

    /// Saves `count` scans as `seed` does, then moves scan `n` to Trash on the day it was scanned, `n` days before
    /// today, as if moved there by hand. Their titles differ from `seed`'s, so both can seed one library.
    @MainActor
    public static func seedTrash(_ store: ScanStore, count: Int, clock: AppClock) async throws {
        let ids = try await save(store, count: count, titled: "Trashed scan", clock: clock) { _ in ScanID() }
        for (index, id) in ids.enumerated() {
            try store.moveToTrash([id], on: clock.today.adding(days: -index, in: clock.calendar))
        }
    }

    /// The ID `seed` gives its scan `index` (from 0), known before it is saved, so `-Request open:<n>` can name the
    /// nth seeded scan (M15). The same in every seeded library.
    public static func scanID(at index: Int) -> ScanID {
        // 5EED0000-0000-4000-8000-0000<index as 8 hex digits>: a valid version 4 UUID no random one is likely to be.
        let byte = { (shift: Int) in UInt8(truncatingIfNeeded: index >> shift) }
        return ScanID(
            uuid: UUID(
                uuid: (0x5E, 0xED, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, byte(24), byte(16), byte(8), byte(0))))
    }

    /// The saved scans' IDs, in order: "<title> 1" first. `id` gives scan `n` (from 0) its ID.
    @MainActor
    private static func save(
        _ store: ScanStore, count: Int, titled prefix: String, clock: AppClock, id makeID: (Int) -> ScanID
    ) async throws -> [ScanID] {
        let now = clock.now()
        let collections = BuiltInCollection.allCases
        var ids: [ScanID] = []
        for index in 0..<count {
            let title = "\(prefix) \(index + 1)"
            let collection = collections[index % collections.count]
            let pageLines = (1...(collection == .documents ? documentPageCount : 1)).map { [title, "Page \($0)"] }
            let pages = pageLines.map { lines in
                SyntheticPages.page(lines: lines.map { ($0, titleSize) }, size: pageSize)
            }
            let scannedAt = clock.calendar.date(byAdding: .day, value: -index, to: now) ?? now
            let id = makeID(index)
            try await store.save(
                ScanDraft(
                    id: id,
                    title: title,
                    collection: collection,
                    scannedAt: scannedAt,
                    expiryOverride: nil,
                    pages: pages,
                    // What reading the pages finds, as the reader joins it: each page's lines, a blank line between
                    // pages.
                    searchText: pageLines.map { $0.joined(separator: "\n") }.joined(separator: "\n\n"),
                    searchWords: hiddenWords[collection] ?? [],
                    searchWordsVersion: seededWordsVersion
                ))
            ids.append(id)
        }
        return ids
    }
}
