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
