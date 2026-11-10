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

/// A copy of a fixture store (three synthetic scans), so migrating it never touches the fixture. `LibraryV1` is the
/// store plan 1 wrote; `LibraryV2` the one plan 3 wrote.
private func storeCopy(_ name: String) throws -> URL {
    let fixture = try #require(
        Bundle.module.url(forResource: name, withExtension: "store", subdirectory: "Fixtures"))
    let copy = try temporaryFolder().appending(path: "Library.store")
    try FileManager.default.copyItem(at: fixture, to: copy)
    return copy
}

@MainActor
@Test func v1StoreStillOpens() throws {
    let container = try ScanStore.makeContainer(storeURL: try storeCopy("LibraryV1"))

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
    #expect(scans.allSatisfy { !$0.isFavorite })
    let searchText = try ModelContext(container).fetch(
        FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.scannedAt)])
    ).map(\.searchText)
    #expect(searchText == ["city pharmacy batteries aa", "library card", "bluebird cafe"])
}

@MainActor
@Test func v2StoreOpensAsV3WithEveryScan() throws {
    let container = try ScanStore.makeContainer(storeURL: try storeCopy("LibraryV2"))

    let store = ScanStore(
        container: container,
        files: PageFileStore(
            location: LibraryLocation(root: try temporaryFolder(), caches: try temporaryFolder()),
            fileSystem: LocalFileSystem()),
        clock: octoberTwelfth)
    let scans = store.scans

    #expect(scans.map(\.title) == ["Bluebird Café", "Library Card", "City Pharmacy"])
    #expect(scans.map(\.collection) == [.notes, .wallet, .receipts])
    #expect(scans.map(\.scannedAt) == [noon(10, 9), noon(10, 5), noon(10, 1)])
    #expect(scans.map(\.expiryOverride) == [nil, .lifespan(.year), nil])
    #expect(scans.map(\.pageCount) == [1, 2, 1])
    #expect(scans.map(\.trashedDay) == [nil, nil, day(10, 12)])
    #expect(scans.allSatisfy { !$0.isFavorite })
    #expect(store.lifespans == CollectionLifespans.defaults.setting(.month, for: .receipts))
    #expect(
        Set(store.searchTexts().values) == ["Bluebird Café", "Library card", "City Pharmacy batteries AA"])
}

@MainActor
@Test func newStoreIsV3() throws {
    let storeURL = try temporaryFolder().appending(path: "Library.store")
    do {
        let container = try ScanStore.makeContainer(storeURL: storeURL)
        let context = container.mainContext
        let record = CollectionRecord()
        record.collectionKey = BuiltInCollection.receipts.rawValue
        record.lifespanKey = Lifespan.year.rawValue
        context.insert(record)
        let scan = ScanRecord()
        scan.favoriteOrder = 4
        context.insert(scan)
        try context.save()
    }

    let container = try ScanStore.makeContainer(storeURL: storeURL)
    let reopened = try ModelContext(container).fetch(FetchDescriptor<CollectionRecord>())

    #expect(reopened.map(\.collectionKey) == ["receipts"])
    #expect(reopened.map(\.lifespanKey) == ["year"])
    #expect(try ModelContext(container).fetch(FetchDescriptor<ScanRecord>()).map(\.favoriteOrder) == [4])
}
