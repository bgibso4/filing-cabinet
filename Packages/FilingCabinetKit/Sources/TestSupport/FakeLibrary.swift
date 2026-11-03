import Core
import Library
import Observation

/// Test double for `ScanLibrary`: keeps scans in memory and throws exactly what the real store throws.
@MainActor
@Observable
package final class FakeLibrary: ScanLibrary {
    /// Every scan, newest `scannedAt` first, like the real store.
    package private(set) var scans: [ScanSummary]
    /// Thrown by the next `save`, which then keeps nothing, as the real store does.
    package var failNextSave: LibraryError?
    /// Every successfully saved draft, in save order.
    package private(set) var saved: [ScanDraft] = []
    /// The latest search text per scan.
    package private(set) var searchTextUpdates: [ScanID: String] = [:]

    package init(scans: [ScanSummary] = []) {
        self.scans = scans.sorted { $0.scannedAt > $1.scannedAt }
    }

    package func save(_ draft: ScanDraft) async throws(LibraryError) {
        if let failure = failNextSave {
            failNextSave = nil
            throw failure
        }
        saved.append(draft)
        let summary = ScanSummary(
            id: draft.id,
            title: draft.title,
            collection: draft.collection,
            scannedAt: draft.scannedAt,
            expiryOverride: draft.expiryOverride,
            pageCount: draft.pages.count
        )
        scans.append(summary)
        scans.sort { $0.scannedAt > $1.scannedAt }
    }

    package func updateSearchText(_ text: String, for id: ScanID) {
        searchTextUpdates[id] = text
    }
}
