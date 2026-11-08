import Core
import Library
import Observation

/// Test double for `ScanLibrary`: keeps scans in memory and throws exactly what the real store throws.
@MainActor
@Observable
public final class FakeLibrary: ScanLibrary {
    /// Every scan, newest `scannedAt` first, like the real store.
    public private(set) var scans: [ScanSummary]
    /// Thrown by the next `save`, which then keeps nothing, as the real store does.
    package var failNextSave: LibraryError?
    /// How long each `save` takes before its record exists, so a test can finish reading mid-save.
    package var saveDelay = Duration.zero
    /// Every successfully saved draft, in save order.
    package private(set) var saved: [ScanDraft] = []
    /// The latest search text per saved scan.
    package private(set) var searchTextUpdates: [ScanID: String] = [:]

    public init(scans: [ScanSummary] = []) {
        self.scans = scans.sorted { $0.scannedAt > $1.scannedAt }
    }

    public func save(_ draft: ScanDraft) async throws(LibraryError) {
        if saveDelay > .zero {
            // A cancelled wait just ends the delay early; the save still happens.
            try? await Task.sleep(for: saveDelay)
        }
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

    /// Like the real store, text for a scan with no record yet is dropped.
    public func updateSearchText(_ text: String, for id: ScanID) {
        guard scans.contains(where: { $0.id == id }) else { return }
        searchTextUpdates[id] = text
    }
}
