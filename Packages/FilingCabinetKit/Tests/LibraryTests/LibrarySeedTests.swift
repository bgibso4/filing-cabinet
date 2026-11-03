import Core
import Foundation
import TestSupport
import Testing

@testable import Library

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

@MainActor
@Test func seedCyclesCollectionsAndStepsBackADayEach() async throws {
    let base = FileManager.default.temporaryDirectory.appending(path: "LibrarySeedTests-\(UUID().uuidString)")
    let location = LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches"))
    let store = ScanStore(
        container: try ScanStore.makeContainer(storeURL: nil),
        files: PageFileStore(location: location, fileSystem: LocalFileSystem()))
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
    #expect(store.scans.allSatisfy { $0.pageCount == 1 && !$0.title.isEmpty })
    #expect(Set(store.scans.map(\.title)).count == 7)
    #expect(store.scans.allSatisfy { store.pageFileURLs(for: $0.id).count == 1 })
}
