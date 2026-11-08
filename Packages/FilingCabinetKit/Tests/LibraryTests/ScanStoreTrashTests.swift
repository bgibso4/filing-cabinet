import Core
import Foundation
import SwiftData
import Synchronization
import Testing

@testable import Library

/// The real disk, but `removeItem` first reports how many records the container had persisted, and fails
/// while `failsRemovals` is set.
private struct ObservedRemovalFileSystem: FileSystem {
    final class Log: Sendable {
        let recordsAtRemoval = Mutex<[Int]>([])
        let failsRemovals = Mutex(false)
    }

    let container: ModelContainer
    let log = Log()
    let real = LocalFileSystem()

    func createDirectory(at url: URL) throws { try real.createDirectory(at: url) }
    func write(_ data: Data, to url: URL) throws { try real.write(data, to: url) }

    func removeItem(at url: URL) throws {
        // A fresh context sees only what the store has persisted, not its pending changes.
        let count = try ModelContext(container).fetchCount(FetchDescriptor<ScanRecord>())
        log.recordsAtRemoval.withLock { $0.append(count) }
        if log.failsRemovals.withLock({ $0 }) { throw CocoaError(.fileWriteNoPermission) }
        try real.removeItem(at: url)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] { try real.contentsOfDirectory(at: url) }
    func fileExists(at url: URL) -> Bool { real.fileExists(at: url) }
}

@MainActor
@Test func moveToTrashStampsToday() async throws {
    let store = try makeStore()
    let kept = draft("Lease 2026", collection: .documents, scannedAt: noon(10, 5))
    let first = draft("Corner Market", collection: .documents, scannedAt: noon(10, 6))
    let second = draft("City Pharmacy", collection: .receipts, scannedAt: noon(10, 7))
    for scan in [kept, first, second] { try await store.save(scan) }

    try store.moveToTrash([first.id, second.id])

    #expect(store.scans.first { $0.id == kept.id }?.trashedDay == nil)
    #expect(store.scans.first { $0.id == first.id }?.trashedDay == day(10, 12))
    #expect(place(of: first.id, in: store) == .trash(daysLeft: 30, entered: day(10, 12)))
    #expect(place(of: second.id, in: store) == .trash(daysLeft: 30, entered: day(10, 12)))
    #expect(place(of: kept.id, in: store) == .library(.forever))
}

@MainActor
@Test func restoreKeepsForeverAndClearsTrash() async throws {
    let store = try makeStore()
    let scan = draft(collection: .receipts, scannedAt: noon(7, 19), expiryOverride: .lifespan(.week))
    try await store.save(scan)
    try store.moveToTrash([scan.id])

    try store.restore([scan.id])

    let restored = try #require(store.scans.first)
    #expect(restored.trashedDay == nil)
    #expect(restored.expiryOverride == .lifespan(.forever))
    #expect(restored.collection == .receipts)
    #expect(place(of: scan.id, in: store) == .library(.forever))
}

@MainActor
@Test func deleteNowRemovesRecordThenFiles() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let location = temporaryLocation()
    let fileSystem = ObservedRemovalFileSystem(container: container)
    let store = try makeStore(container: container, location: location, fileSystem: fileSystem)
    let kept = draft("Lease 2026")
    let deleted = draft("Corner Market")
    try await store.save(kept)
    try await store.save(deleted)
    try store.moveToTrash([deleted.id])

    try await store.deleteNow([deleted.id])

    // Both folders went after the record was persisted gone: one record left each time.
    #expect(fileSystem.log.recordsAtRemoval.withLock { $0 } == [1, 1])
    #expect(store.scans.map(\.id) == [kept.id])
    #expect(!exists(location.originals(for: deleted.id)))
    #expect(!exists(location.thumbnails(for: deleted.id)))
    #expect(exists(location.originals(for: kept.id)))
}

@MainActor
@Test func fileRemovalFailureLeavesNoRecord() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let location = temporaryLocation()
    let fileSystem = ObservedRemovalFileSystem(container: container)
    let store = try makeStore(container: container, location: location, fileSystem: fileSystem)
    let scan = draft()
    try await store.save(scan)
    fileSystem.log.failsRemovals.withLock { $0 = true }

    try await store.deleteNow([scan.id])

    #expect(store.scans.isEmpty)
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<ScanRecord>()) == 0)
    #expect(exists(location.originals(for: scan.id)))
    #expect(exists(location.thumbnails(for: scan.id)))

    // Next launch: the leftover files are orphans, and cleanup removes them.
    fileSystem.log.failsRemovals.withLock { $0 = false }
    await store.removeOrphanedFiles()

    #expect(!exists(location.originals(for: scan.id)))
    #expect(!exists(location.thumbnails(for: scan.id)))
}

@MainActor
@Test func failedDeleteKeepsRecordAndFiles() async throws {
    var failPersist = false
    let location = temporaryLocation()
    let store = try makeStore(
        location: location,
        persist: { context in
            if failPersist { throw CocoaError(.fileWriteUnknown) }
            try context.save()
        })
    let scan = draft()
    try await store.save(scan)
    failPersist = true

    await #expect(throws: LibraryError.writeFailed) {
        try await store.deleteNow([scan.id])
    }

    #expect(store.scans.map(\.id) == [scan.id])
    #expect(exists(location.originals(for: scan.id)))
}

@MainActor
@Test func purgeDeletesOnlyGoneScans() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let location = temporaryLocation()
    let fileSystem = ObservedRemovalFileSystem(container: container)
    let store = try makeStore(container: container, location: location, fileSystem: fileSystem)
    // A week from Aug 1: in Trash Aug 8 to Sep 6, so gone by Oct 12.
    let gone = draft("Parking stub", collection: .throwaways, scannedAt: noon(8, 1))
    // A week from Oct 3: in Trash since Oct 10.
    let inTrash = draft("Coat check", collection: .throwaways, scannedAt: noon(10, 3))
    let kept = draft("Lease 2026", collection: .documents, scannedAt: noon(8, 1))
    for scan in [gone, inTrash, kept] { try await store.save(scan) }

    let purged = await store.purgeTrash()

    #expect(purged == 1)
    #expect(Set(store.scans.map(\.id)) == [inTrash.id, kept.id])
    // Both of the gone scan's folders went after its record was persisted gone.
    #expect(fileSystem.log.recordsAtRemoval.withLock { $0 } == [2, 2])
    #expect(!exists(location.originals(for: gone.id)))
    #expect(exists(location.originals(for: inTrash.id)))
    #expect(exists(location.originals(for: kept.id)))
}

@MainActor
@Test func purgeWithNothingGoneDeletesNothing() async throws {
    let store = try makeStore()
    try await store.save(draft("Coat check", collection: .throwaways, scannedAt: noon(10, 3)))

    #expect(await store.purgeTrash() == 0)
    #expect(store.scans.count == 1)
}

@MainActor
@Test func emptyTrashDeletesEveryTrashedScan() async throws {
    let location = temporaryLocation()
    let store = try makeStore(location: location)
    let moved = draft("Lease 2025", collection: .documents, scannedAt: noon(10, 1))
    let expired = draft("Coat check", collection: .throwaways, scannedAt: noon(10, 3))
    let kept = draft("Lease 2026", collection: .documents, scannedAt: noon(10, 2))
    for scan in [moved, expired, kept] { try await store.save(scan) }
    try store.moveToTrash([moved.id])

    let deleted = try await store.emptyTrash()

    #expect(deleted == 2)
    #expect(store.scans.map(\.id) == [kept.id])
    #expect(!exists(location.originals(for: moved.id)))
    #expect(!exists(location.originals(for: expired.id)))
    #expect(exists(location.originals(for: kept.id)))
}

@MainActor
@Test func failedEmptyTrashKeepsEverything() async throws {
    var failPersist = false
    let location = temporaryLocation()
    let store = try makeStore(
        location: location,
        persist: { context in
            if failPersist { throw CocoaError(.fileWriteUnknown) }
            try context.save()
        })
    let expired = draft("Coat check", collection: .throwaways, scannedAt: noon(10, 3))
    try await store.save(expired)
    failPersist = true

    await #expect(throws: LibraryError.writeFailed) {
        try await store.emptyTrash()
    }

    #expect(store.scans.map(\.id) == [expired.id])
    #expect(exists(location.originals(for: expired.id)))
}
