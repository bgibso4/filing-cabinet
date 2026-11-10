import Core
import Foundation
import TestSupport
import Testing

@testable import Library

@MainActor
@Test func seedCyclesCollectionsAndStepsBackADayEach() async throws {
    let base = FileManager.default.temporaryDirectory.appending(path: "LibrarySeedTests-\(UUID().uuidString)")
    let location = LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches"))
    let store = try makeStore(location: location)
    // 2026-10-12 at 12:00 UTC.
    let now = Date(timeIntervalSince1970: 1_791_806_400)

    try await LibrarySeed.seed(store, count: 7, clock: .fixed(now, calendar: utc))

    // Newest first, so the store's order is the seed order.
    #expect(store.scans.count == 7)
    #expect(
        store.scans.map(\.collection) == [.wallet, .receipts, .notes, .documents, .throwaways, .wallet, .receipts])
    #expect(
        store.scans.map { CalendarDay($0.scannedAt, in: utc) }
            == (0..<7).map {
                CalendarDay(year: 2026, month: 10, day: 12 - $0)
            })
    #expect(store.scans.allSatisfy { !$0.title.isEmpty })
    // Documents' scans have three pages, so a journey has pages to swipe through.
    #expect(store.scans.map(\.pageCount) == [1, 1, 1, 3, 1, 1, 1])
    #expect(Set(store.scans.map(\.title)).count == 7)
    #expect(store.scans.allSatisfy { store.pageFileURLs(for: $0.id).count == $0.pageCount })
}

@MainActor
@Test func seededTextIsWhatThePagesShow() async throws {
    let base = FileManager.default.temporaryDirectory.appending(path: "LibrarySeedTests-\(UUID().uuidString)")
    let location = LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches"))
    let store = try makeStore(location: location)
    let now = Date(timeIntervalSince1970: 1_791_806_400)

    try await LibrarySeed.seed(store, count: 4, clock: .fixed(now, calendar: utc))

    let texts = store.searchTexts()
    #expect(texts[store.scans[0].id] == "Sample scan 1\nPage 1")
    // Documents' three pages, in order.
    #expect(
        texts[store.scans[3].id]
            == "Sample scan 4\nPage 1\nSample scan 4\nPage 2\nSample scan 4\nPage 3")
}

@MainActor
@Test func seedTrashMovesEachScanToTrashADayEarlierThanTheLast() async throws {
    let base = FileManager.default.temporaryDirectory.appending(path: "LibrarySeedTests-\(UUID().uuidString)")
    let location = LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches"))
    let store = try makeStore(location: location)
    let clock = octoberTwelfth

    try await LibrarySeed.seed(store, count: 2, clock: clock)
    try await LibrarySeed.seedTrash(store, count: 3, clock: clock)

    let trashed = store.scans.filter { $0.trashedDay != nil }
    #expect(store.scans.count == 5)
    #expect(
        Set(trashed.map(\.trashedDay)) == Set((0..<3).map { CalendarDay(year: 2026, month: 10, day: 12 - $0) }))
    // Every trashed scan was scanned on the day it went to Trash.
    #expect(trashed.allSatisfy { CalendarDay($0.scannedAt, in: utc) == $0.trashedDay })
    // Titles never repeat across the two seeds, so a journey can find each scan by its title.
    #expect(Set(store.scans.map(\.title)).count == 5)
    #expect(store.scans.allSatisfy { store.pageFileURLs(for: $0.id).count == $0.pageCount })
}

@MainActor
@Test func seedFavoritesTheFirstScansInSeedOrder() async throws {
    let store = try makeStore()

    try await LibrarySeed.seed(store, count: 4, favorites: 2, clock: octoberTwelfth)

    // Newest first, so the store's order is the seed order.
    #expect(store.scans.map(\.favoriteOrder) == [0, 1, nil, nil])
}
