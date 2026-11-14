import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
private let noon = oct12.date(in: utc).addingTimeInterval(12 * 3600)
nonisolated private let jpeg = Data([0xFF, 0xD8, 0xFF])

/// A scan kept forever, scanned ten days before Oct 12.
private func scan(
    _ title: String,
    in collection: BuiltInCollection = .receipts,
    pages: Int = 1,
    expiry: ExpiryOverride? = .lifespan(.forever),
    trashedDay: CalendarDay? = nil
) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: noon.addingTimeInterval(-10 * 86_400),
        expiryOverride: expiry,
        pageCount: pages,
        trashedDay: trashedDay)
}

/// A sync running over a fake library and index, a movable clock and fresh preferences.
@MainActor
private struct SyncHarness {
    let now = MovableNow(noon)
    let library: FakeLibrary
    let today: Today
    let index = FakeSpotlightIndex()
    let preferences: AppPreferences
    private let fresh: FreshDefaults
    let sync: SpotlightSync
    private let running: Task<Void, Never>

    init(_ scans: [ScanSummary], storedVersion: Int = SpotlightSync.version, failFirstCall: Bool = false) throws {
        let now = now
        let clock = AppClock(now: { now.now }, calendar: utc, locale: Locale(identifier: "en_US"))
        fresh = try FreshDefaults()
        library = FakeLibrary(scans: scans, clock: clock)
        today = Today(clock: clock)
        preferences = AppPreferences(defaults: fresh.defaults)
        preferences.spotlightVersion = storedVersion
        if failFirstCall { index.failNextCall() }
        let sync = SpotlightSync(
            library: library, today: today, index: index, thumbnails: { _ in jpeg }, preferences: preferences)
        self.sync = sync
        running = Task { await sync.run() }
    }

    /// The indexed titles, sorted.
    var titles: [String] { index.items.values.map(\.title).sorted() }

    func cleanUp() {
        running.cancel()
        fresh.cleanUp()
    }
}

/// Polls for up to 5 s until `condition` holds; false if it never did.
@MainActor
private func eventually(_ condition: () -> Bool) async throws -> Bool {
    for _ in 0..<500 {
        if condition() { return true }
        try await Task.sleep(for: .milliseconds(10))
    }
    return false
}

@MainActor
@Test func firstStartIndexesEverythingInTheLibrary() async throws {
    let receipt = scan("City Pharmacy", pages: 3)
    let note = scan("Lecture", in: .notes)
    let harness = try SyncHarness([receipt, note])
    defer { harness.cleanUp() }

    #expect(try await eventually { harness.titles == ["City Pharmacy", "Lecture"] })
    #expect(harness.index.items[receipt.id]?.detail == "Receipts · 3 pages")
    #expect(harness.index.items[receipt.id]?.thumbnail == jpeg)
}

@MainActor
@Test func trashedScansAreNeverIndexed() async throws {
    let kept = scan("Kept")
    let trashed = scan("Trashed", trashedDay: oct12)
    // Its last day was yesterday, so it entered Trash on its own today.
    let expired = scan("Expired", expiry: .lastDay(oct12.adding(days: -1, in: utc)))
    let harness = try SyncHarness([kept, trashed, expired])
    defer { harness.cleanUp() }

    #expect(try await eventually { harness.titles == ["Kept"] })
}

@MainActor
@Test func expiryIsTheDayTheScanEntersTrash() async throws {
    let receipt = scan("City Pharmacy", expiry: .lastDay(oct12.adding(days: 5, in: utc)))
    let note = scan("Lecture", in: .notes)
    let harness = try SyncHarness([receipt, note])
    defer { harness.cleanUp() }

    #expect(try await eventually { harness.index.items.count == 2 })
    #expect(harness.index.items[receipt.id]?.expires == oct12.adding(days: 6, in: utc).date(in: utc))
    #expect(harness.index.items[note.id]?.expires == nil)
}

@MainActor
@Test func renameUpdatesTheItem() async throws {
    let receipt = scan("City Pharmacy")
    let other = scan("Lecture")
    let harness = try SyncHarness([receipt, other])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.items.count == 2 })

    try harness.library.rename(receipt.id, to: "Corner Market")

    #expect(try await eventually { harness.titles == ["Corner Market", "Lecture"] })
    // Only the renamed scan is sent again, still with its thumbnail.
    #expect(harness.index.calls.last == .index([receipt.id]))
    #expect(harness.index.items[receipt.id]?.thumbnail == jpeg)
}

@MainActor
@Test func moveUpdatesTheDetail() async throws {
    let receipt = scan("City Pharmacy")
    let harness = try SyncHarness([receipt])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.items[receipt.id]?.detail == "Receipts · 1 page" })

    try harness.library.move(receipt.id, to: .notes)

    #expect(try await eventually { harness.index.items[receipt.id]?.detail == "Notes · 1 page" })
}

@MainActor
@Test func trashRemovesAndRestoreAddsBack() async throws {
    let receipt = scan("City Pharmacy")
    let harness = try SyncHarness([receipt, scan("Lecture")])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.items.count == 2 })

    try harness.library.moveToTrash([receipt.id])
    #expect(try await eventually { harness.titles == ["Lecture"] })
    #expect(harness.index.calls.last == .remove([receipt.id]))

    try harness.library.restore([receipt.id])
    #expect(try await eventually { harness.titles == ["City Pharmacy", "Lecture"] })
}

@MainActor
@Test func deleteNowAndEmptyTrashRemove() async throws {
    let first = scan("City Pharmacy")
    let second = scan("Corner Market")
    let harness = try SyncHarness([first, second, scan("Lecture")])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.items.count == 3 })

    try await harness.library.deleteNow([first.id])
    #expect(try await eventually { harness.titles == ["Corner Market", "Lecture"] })

    try harness.library.moveToTrash([second.id])
    _ = try await harness.library.emptyTrash()
    #expect(try await eventually { harness.titles == ["Lecture"] })
    // Removed once, when it entered Trash: emptying Trash has nothing left to remove.
    #expect(harness.index.calls.filter { $0 == .remove([second.id]) }.count == 1)
}

@MainActor
@Test func expiryRemoves() async throws {
    // Its last day is today: tomorrow it enters Trash on its own, and Trash's purge can only delete it after that.
    let receipt = scan("City Pharmacy", expiry: .lastDay(oct12))
    let harness = try SyncHarness([receipt, scan("Lecture")])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.items.count == 2 })

    harness.now.set(noon.addingTimeInterval(86_400))
    harness.today.refresh()

    #expect(try await eventually { harness.titles == ["Lecture"] })
}

@MainActor
@Test func failedCallIsRetriedNextSync() async throws {
    let receipt = scan("City Pharmacy")
    let other = scan("Lecture")
    let harness = try SyncHarness([receipt, other])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.items.count == 2 })

    harness.index.failNextCall()
    try harness.library.rename(receipt.id, to: "Corner Market")
    // The first pass made two calls; the rename's failed call is the third.
    #expect(try await eventually { harness.index.calls.count == 3 })
    #expect(harness.titles == ["City Pharmacy", "Lecture"])

    try harness.library.rename(other.id, to: "Seminar")

    #expect(try await eventually { harness.titles == ["Corner Market", "Seminar"] })
}

@MainActor
@Test func versionBumpReindexesEverything() async throws {
    let harness = try SyncHarness([scan("City Pharmacy"), scan("Lecture")], storedVersion: SpotlightSync.version - 1)
    defer { harness.cleanUp() }

    #expect(try await eventually { harness.preferences.spotlightVersion == SpotlightSync.version })
    #expect(harness.index.calls.first == .removeAll)
    #expect(harness.titles == ["City Pharmacy", "Lecture"])
}

@MainActor
@Test func failedRebuildKeepsTheOldVersion() async throws {
    let receipt = scan("City Pharmacy")
    let harness = try SyncHarness([receipt], storedVersion: SpotlightSync.version - 1, failFirstCall: true)
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.calls == [.removeAll] })
    #expect(harness.preferences.spotlightVersion == SpotlightSync.version - 1)

    try harness.library.rename(receipt.id, to: "Corner Market")

    #expect(try await eventually { harness.preferences.spotlightVersion == SpotlightSync.version })
    #expect(harness.index.calls == [.removeAll, .removeAll, .index([receipt.id])])
}

@MainActor
@Test func everyStartBeginsClean() async throws {
    let receipt = scan("City Pharmacy")
    let harness = try SyncHarness([receipt])
    defer { harness.cleanUp() }

    // Whatever a removal that failed in an earlier run left behind goes first (the sync's own state starts empty).
    #expect(try await eventually { harness.index.calls == [.removeAll, .index([receipt.id])] })
}

@MainActor
@Test func failedFirstPassStartsCleanAgain() async throws {
    let receipt = scan("City Pharmacy")
    let harness = try SyncHarness([receipt], failFirstCall: true)
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.index.calls == [.removeAll] })

    harness.sync.syncAgain()

    #expect(try await eventually { harness.index.calls == [.removeAll, .removeAll, .index([receipt.id])] })
}

@MainActor
@Test func sameVersionDoesNotReindex() async throws {
    let receipt = scan("City Pharmacy")
    let harness = try SyncHarness([receipt])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.titles == ["City Pharmacy"] })

    try harness.library.rename(receipt.id, to: "Corner Market")

    #expect(try await eventually { harness.titles == ["Corner Market"] })
    #expect(harness.index.calls.filter { $0 == .removeAll }.count == 1)
}

@MainActor
@Test func comingBackRetriesAFailedCall() async throws {
    let receipt = scan("City Pharmacy")
    let harness = try SyncHarness([receipt])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.titles == ["City Pharmacy"] })

    // As while the phone is locked: the protected index refuses the call.
    harness.index.failNextCall()
    try harness.library.rename(receipt.id, to: "Corner Market")
    // The first pass made two calls; the rename's failed call is the third.
    #expect(try await eventually { harness.index.calls.count == 3 })
    #expect(harness.titles == ["City Pharmacy"])

    harness.sync.syncAgain()

    #expect(try await eventually { harness.titles == ["Corner Market"] })
}

@MainActor
@Test func onlyTitlesAreIndexed() async throws {
    let harness = try SyncHarness([])
    defer { harness.cleanUp() }
    let draft = ScanDraft(
        id: ScanID(),
        title: "City Pharmacy",
        collection: .receipts,
        scannedAt: noon,
        expiryOverride: nil,
        pages: [SyntheticPages.receipt()],
        searchText: "ASPIRIN 4.99",
        searchWords: ["medicine"],
        searchWordsVersion: 1)

    try await harness.library.save(draft)

    #expect(try await eventually { harness.index.items[draft.id] != nil })
    // The item holds the title, the detail, the thumbnail and its last day: no text and no words.
    let item = try #require(harness.index.items[draft.id])
    let expected = SpotlightItem(
        id: draft.id,
        title: "City Pharmacy",
        detail: "Receipts · 1 page",
        thumbnail: jpeg,
        expires: item.expires)
    #expect(item == expected)
}

@MainActor
@Test func detailUsesMiddotAndPlural() {
    #expect(SpotlightSync.detail(scan("City Pharmacy", pages: 3)) == "Receipts · 3 pages")
    #expect(SpotlightSync.detail(scan("Lecture", in: .notes)) == "Notes · 1 page")
}
