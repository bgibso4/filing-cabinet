import Core
import Foundation
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
    /// Thrown by the next edit (rename to Delete now), which then changes nothing, as the real store does.
    package var failNextEdit: LibraryError?
    /// How long each `save` takes before its record exists, so a test can finish reading mid-save.
    package var saveDelay = Duration.zero
    /// Every successfully saved draft, in save order.
    package private(set) var saved: [ScanDraft] = []
    /// The latest search text per saved scan.
    package private(set) var searchTextUpdates: [ScanID: String] = [:]

    /// Today, for Trash days.
    private let clock: AppClock

    /// Lives on Oct 12, 2026 in GMT, the snapshot fixtures' day.
    public convenience init(scans: [ScanSummary] = []) {
        self.init(scans: scans, clock: Self.octoberTwelfth)
    }

    package init(scans: [ScanSummary], clock: AppClock) {
        self.scans = scans.sorted { $0.scannedAt > $1.scannedAt }
        self.clock = clock
    }

    public var lifespans: CollectionLifespans { .defaults }

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

    public func rename(_ id: ScanID, to title: String) throws(LibraryError) {
        try edit([id]) { $0.title = title }
    }

    public func move(_ id: ScanID, to collection: BuiltInCollection) throws(LibraryError) {
        let today = clock.today
        let lifespans = lifespans
        try edit([id]) { scan in
            scan.trashedDay = scan.trashedDayAfterMoving(
                to: collection, lifespans: lifespans, today: today, in: clock.calendar)
            scan.collection = collection
        }
    }

    public func setExpiry(_ override: ExpiryOverride?, for id: ScanID) throws(LibraryError) {
        try edit([id]) { $0.expiryOverride = override }
    }

    public func moveToTrash(_ ids: [ScanID]) throws(LibraryError) {
        let today = clock.today
        try edit(ids) { $0.trashedDay = today }
    }

    public func restore(_ ids: [ScanID]) throws(LibraryError) {
        try edit(ids) { scan in
            scan.trashedDay = nil
            scan.expiryOverride = .lifespan(.forever)
        }
    }

    public func deleteNow(_ ids: [ScanID]) async throws(LibraryError) {
        try spendFailure()
        scans.removeAll { ids.contains($0.id) }
    }

    /// Changes each listed scan, unless `failNextEdit` fails it first.
    private func edit(_ ids: [ScanID], _ change: (inout ScanSummary) -> Void) throws(LibraryError) {
        try spendFailure()
        for index in scans.indices where ids.contains(scans[index].id) {
            change(&scans[index])
        }
    }

    private func spendFailure() throws(LibraryError) {
        if let failure = failNextEdit {
            failNextEdit = nil
            throw failure
        }
    }

    private static let octoberTwelfth: AppClock = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let noon = DateComponents(calendar: calendar, timeZone: .gmt, year: 2026, month: 10, day: 12, hour: 12)
        // The components always make a date; the fallback only satisfies the optional.
        return AppClock.fixed(noon.date ?? Date(timeIntervalSince1970: 0), calendar: calendar)
    }()
}
