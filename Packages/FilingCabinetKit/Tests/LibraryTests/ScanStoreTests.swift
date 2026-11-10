import Core
import CoreGraphics
import Dispatch
import Foundation
import SwiftData
import Synchronization
import TestSupport
import Testing

@testable import Library

/// The real disk, recording every file written.
private struct RecordingFileSystem: FileSystem {
    final class Log: Sendable {
        let writes = Mutex<[URL]>([])
    }

    let log = Log()
    let real = LocalFileSystem()

    func createDirectory(at url: URL) throws { try real.createDirectory(at: url) }

    func write(_ data: Data, to url: URL) throws {
        try real.write(data, to: url)
        log.writes.withLock { $0.append(url) }
    }

    func removeItem(at url: URL) throws { try real.removeItem(at: url) }
    func contentsOfDirectory(at url: URL) throws -> [URL] { try real.contentsOfDirectory(at: url) }
    func fileExists(at url: URL) -> Bool { real.fileExists(at: url) }
}

/// The real disk, but after writing `holdAfter` it reports through `written` and holds until the test
/// signals `release`. `FileSystem` is synchronous, so the hold is a semaphore wait on the write's thread.
private struct HoldingFileSystem: FileSystem {
    let holdAfter: String
    let written: AsyncStream<Void>.Continuation
    let release: DispatchSemaphore
    let real = LocalFileSystem()

    func createDirectory(at url: URL) throws { try real.createDirectory(at: url) }

    func write(_ data: Data, to url: URL) throws {
        try real.write(data, to: url)
        if url.lastPathComponent == holdAfter {
            written.yield()
            release.wait()
        }
    }

    func removeItem(at url: URL) throws { try real.removeItem(at: url) }
    func contentsOfDirectory(at url: URL) throws -> [URL] { try real.contentsOfDirectory(at: url) }
    func fileExists(at url: URL) -> Bool { real.fileExists(at: url) }
}

private struct PersistFailed: Error {}

/// How many records the container has persisted, seen through a fresh context.
@MainActor
private func persistedCount(in container: ModelContainer) -> Int {
    (try? ModelContext(container).fetchCount(FetchDescriptor<ScanRecord>())) ?? -1  // -1 fails the expectation
}

@MainActor
@Test func savedScanAppearsNewestFirst() async throws {
    let location = temporaryLocation()
    let store = try makeStore(location: location)
    let older = draft("Older", scannedAt: Date(timeIntervalSince1970: 1_000), pages: 2)
    let newer = draft("Newer", scannedAt: Date(timeIntervalSince1970: 2_000))

    try await store.save(older)
    try await store.save(newer)

    #expect(store.scans.map(\.id) == [newer.id, older.id])
    #expect(store.scans.map(\.title) == ["Newer", "Older"])
    #expect(store.scans.last?.pageCount == 2)
    #expect(store.scans.last?.collection == .receipts)
    #expect(
        store.pageFileURLs(for: older.id) == [
            location.originals(for: older.id).appending(path: "page-1.heic"),
            location.originals(for: older.id).appending(path: "page-2.heic"),
        ])
    #expect(store.pageFileURLs(for: older.id).allSatisfy(exists))
    #expect(store.pageFileURLs(for: ScanID()).isEmpty)
}

@MainActor
@Test func saveWritesFilesBeforeTheRecord() async throws {
    let location = temporaryLocation()
    let fileSystem = RecordingFileSystem()
    var writesAtPersist: [URL] = []
    var insertedAtPersist = 0
    let store = ScanStore(
        container: try ScanStore.makeContainer(storeURL: nil),
        files: PageFileStore(location: location, fileSystem: fileSystem),
        clock: octoberTwelfth,
        persist: { context in
            writesAtPersist = fileSystem.log.writes.withLock { $0 }
            insertedAtPersist = context.insertedModelsArray.count
            try context.save()
        })
    let scan = draft(pages: 2)

    try await store.save(scan)

    #expect(writesAtPersist.count == 4)
    #expect(writesAtPersist.allSatisfy(exists))
    #expect(insertedAtPersist == 1)
}

@MainActor
@Test func diskFullOnFilesInsertsNothing() async throws {
    let location = temporaryLocation()
    let container = try ScanStore.makeContainer(storeURL: nil)
    var persisted = false
    let store = ScanStore(
        container: container,
        files: PageFileStore(location: location, fileSystem: FailOnceFileSystem(LocalFileSystem())),
        clock: octoberTwelfth,
        persist: { context in
            persisted = true
            try context.save()
        })
    let scan = draft()

    await #expect(throws: LibraryError.diskFull) {
        try await store.save(scan)
    }

    #expect(!persisted)
    #expect(store.scans.isEmpty)
    #expect(persistedCount(in: container) == 0)
    #expect(!exists(location.originals(for: scan.id)))
    #expect(!exists(location.thumbnails(for: scan.id)))
}

@MainActor
@Test func contextSaveFailureRemovesFilesAndRecord() async throws {
    let location = temporaryLocation()
    let container = try ScanStore.makeContainer(storeURL: nil)
    let store = ScanStore(
        container: container,
        files: PageFileStore(location: location, fileSystem: LocalFileSystem()),
        clock: octoberTwelfth,
        persist: { _ in throw PersistFailed() })
    let scan = draft(pages: 2)

    await #expect(throws: LibraryError.writeFailed) {
        try await store.save(scan)
    }

    #expect(store.scans.isEmpty)
    #expect(container.mainContext.insertedModelsArray.isEmpty)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<ScanRecord>()) == 0)
    #expect(persistedCount(in: container) == 0)
    #expect(!exists(location.originals(for: scan.id)))
    #expect(!exists(location.thumbnails(for: scan.id)))
}

@MainActor
@Test func orphanedFoldersAreRemovedAtLaunch() async throws {
    let location = temporaryLocation()
    let store = try makeStore(location: location)
    let real = draft()
    try await store.save(real)
    // Killed between writing files and inserting the record: originals and thumbnails with no record.
    let orphan = ScanID()
    let thumbnailOnly = ScanID()
    try FileManager.default.createDirectory(at: location.originals(for: orphan), withIntermediateDirectories: true)
    try Data([1]).write(to: location.originals(for: orphan).appending(path: "page-1.heic"))
    try FileManager.default.createDirectory(at: location.thumbnails(for: orphan), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
        at: location.thumbnails(for: thumbnailOnly), withIntermediateDirectories: true)
    try Data([1]).write(to: location.thumbnails(for: thumbnailOnly).appending(path: "page-1.jpg"))

    await store.removeOrphanedFiles()

    #expect(!exists(location.originals(for: orphan)))
    #expect(!exists(location.thumbnails(for: orphan)))
    #expect(!exists(location.thumbnails(for: thumbnailOnly)))
    #expect(exists(location.originals(for: real.id).appending(path: "page-1.heic")))
    #expect(exists(location.thumbnails(for: real.id).appending(path: "page-1.jpg")))
    #expect(store.scans.map(\.id) == [real.id])
}

@MainActor
@Test func orphanCleanupFetchesOnce() async throws {
    let location = temporaryLocation()
    var fetches = 0
    let store = ScanStore(
        container: try ScanStore.makeContainer(storeURL: nil),
        files: PageFileStore(location: location, fileSystem: LocalFileSystem()),
        clock: octoberTwelfth,
        persist: nil,
        fetch: { context, descriptor in
            fetches += 1
            return try context.fetch(descriptor)
        })
    let real = draft()
    try await store.save(real)
    let orphans = (1...99).map { _ in ScanID() }
    for orphan in orphans {
        try FileManager.default.createDirectory(at: location.originals(for: orphan), withIntermediateDirectories: true)
    }
    let fetchesBefore = fetches

    await store.removeOrphanedFiles()

    #expect(fetches - fetchesBefore == 1)
    #expect(!orphans.contains { exists(location.originals(for: $0)) })
    #expect(exists(location.originals(for: real.id).appending(path: "page-1.heic")))
    #expect(store.scans.map(\.id) == [real.id])
}

@MainActor
@Test func cleanupSkipsASaveInFlight() async throws {
    let location = temporaryLocation()
    let (written, writtenContinuation) = AsyncStream.makeStream(of: Void.self)
    let release = DispatchSemaphore(value: 0)
    let store = ScanStore(
        container: try ScanStore.makeContainer(storeURL: nil),
        files: PageFileStore(
            location: location,
            fileSystem: HoldingFileSystem(holdAfter: "page-1.jpg", written: writtenContinuation, release: release)),
        clock: octoberTwelfth)
    let scan = draft()

    let saving = Task { try await store.save(scan) }
    var events = written.makeAsyncIterator()
    await events.next()  // every file is on disk; the record is not yet inserted
    await store.removeOrphanedFiles()
    release.signal()
    try await saving.value

    #expect(exists(location.originals(for: scan.id).appending(path: "page-1.heic")))
    #expect(exists(location.thumbnails(for: scan.id).appending(path: "page-1.jpg")))
    #expect(store.scans.map(\.id) == [scan.id])
}

@MainActor
@Test func searchTextCanArriveAfterSave() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let store = try makeStore(container: container)
    let scan = draft(searchText: nil)
    try await store.save(scan)

    let scansBefore = store.scans
    store.updateSearchText("city pharmacy batteries aa", for: scan.id)

    let records = try ModelContext(container).fetch(FetchDescriptor<ScanRecord>())
    #expect(records.map(\.searchText) == ["city pharmacy batteries aa"])
    // Search follows the revision; the scans (and so every grid) stay as they were.
    #expect(store.searchTextRevision == 1)
    #expect(store.scans == scansBefore)
    store.updateSearchText("no record", for: ScanID())
    #expect(store.searchTextRevision == 1)
}

@MainActor
@Test func reopeningTheStoreKeepsScans() async throws {
    let location = temporaryLocation()
    try FileManager.default.createDirectory(at: location.root, withIntermediateDirectories: true)
    let files = PageFileStore(location: location, fileSystem: LocalFileSystem())
    let scan = draft("Bluebird Café", searchText: "bluebird")
    do {
        let store = ScanStore(
            container: try ScanStore.makeContainer(storeURL: location.storeURL), files: files, clock: octoberTwelfth)
        try await store.save(scan)
    }

    let reopened = ScanStore(
        container: try ScanStore.makeContainer(storeURL: location.storeURL), files: files, clock: octoberTwelfth)

    #expect(reopened.scans.map(\.id) == [scan.id])
    #expect(reopened.scans.first?.title == "Bluebird Café")
    #expect(reopened.pageFileURLs(for: scan.id).allSatisfy(exists))
}
