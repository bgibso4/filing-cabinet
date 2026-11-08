import Core
import Foundation
import SwiftData
import Testing

@testable import Library

/// A fresh folder under the temporary directory.
private func temporaryFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appending(path: "MigrationTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

/// A copy of the store plan 1 wrote (three synthetic scans), so migrating it never touches the fixture.
private func v1StoreCopy() throws -> URL {
    let fixture = try #require(
        Bundle.module.url(forResource: "LibraryV1", withExtension: "store", subdirectory: "Fixtures"))
    let copy = try temporaryFolder().appending(path: "Library.store")
    try FileManager.default.copyItem(at: fixture, to: copy)
    return copy
}

@MainActor
@Test func v1StoreOpensAsV2WithEveryScan() throws {
    let container = try ScanStore.makeContainer(storeURL: try v1StoreCopy())

    let scans = ScanStore(
        container: container,
        files: PageFileStore(
            location: LibraryLocation(root: try temporaryFolder(), caches: try temporaryFolder()),
            fileSystem: LocalFileSystem()),
        clock: octoberTwelfth
    ).scans

    #expect(scans.map(\.title) == ["Bluebird Café", "Library Card", "City Pharmacy"])
    #expect(scans.map(\.collection) == [.notes, .wallet, .receipts])
    #expect(
        scans.map(\.expiryOverride) == [
            .lifespan(.year), .lastDay(CalendarDay(year: 2027, month: 3, day: 3)), nil,
        ])
    #expect(scans.map(\.pageCount) == [1, 2, 1])
    #expect(scans.allSatisfy { $0.trashedDay == nil })
    let searchText = try ModelContext(container).fetch(
        FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.scannedAt)])
    ).map(\.searchText)
    #expect(searchText == ["city pharmacy batteries aa", "library card", "bluebird cafe"])
}

@MainActor
@Test func newStoreIsV2() throws {
    let storeURL = try temporaryFolder().appending(path: "Library.store")
    do {
        let container = try ScanStore.makeContainer(storeURL: storeURL)
        let context = container.mainContext
        let record = CollectionRecord()
        record.collectionKey = BuiltInCollection.receipts.rawValue
        record.lifespanKey = Lifespan.year.rawValue
        context.insert(record)
        try context.save()
    }

    let container = try ScanStore.makeContainer(storeURL: storeURL)
    let reopened = try ModelContext(container).fetch(FetchDescriptor<CollectionRecord>())

    #expect(reopened.map(\.collectionKey) == ["receipts"])
    #expect(reopened.map(\.lifespanKey) == ["year"])
}
