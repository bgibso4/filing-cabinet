import Core
import Foundation
import Testing

@testable import Library

@MainActor
@Test func savedDraftKeepsItsWords() async throws {
    let store = try makeStore()
    let scan = draft(
        "Licence",
        collection: .wallet,
        scannedAt: noon(10, 1),
        searchWords: ["ID", "driving licence"],
        searchWordsVersion: 2)
    let unread = draft("Unread", scannedAt: noon(10, 2))

    try await store.save(scan)
    try await store.save(unread)

    #expect(store.searchWords()[scan.id] == ["ID", "driving licence"])
    #expect(store.searchWords()[unread.id] == [])
    #expect(store.scansNeedingWords(version: 2) == [unread.id])
}

@MainActor
@Test func updateSearchWordsBumpsTheRevision() async throws {
    let store = try makeStore()
    let scan = draft(scannedAt: noon(10, 1))
    try await store.save(scan)
    let before = store.searchTextRevision

    store.updateSearchWords(["receipt", "pharmacy"], version: 1, for: scan.id)

    #expect(store.searchWords()[scan.id] == ["receipt", "pharmacy"])
    #expect(store.searchTextRevision == before + 1)
    #expect(store.scansNeedingWords(version: 1).isEmpty)
}

@MainActor
@Test func updateForAMissingScanIsIgnored() throws {
    let store = try makeStore()

    store.updateSearchWords(["ghost"], version: 1, for: ScanID())

    #expect(store.searchTextRevision == 0)
    #expect(store.searchWords().isEmpty)
}

@MainActor
@Test func emptyWordsStoreAsNoWords() async throws {
    let store = try makeStore()
    let scan = draft(scannedAt: noon(10, 1))
    try await store.save(scan)
    store.updateSearchWords(["a", "b"], version: 1, for: scan.id)

    store.updateSearchWords([], version: 2, for: scan.id)

    #expect(store.searchWords()[scan.id] == [])
    #expect(store.scansNeedingWords(version: 2).isEmpty)
}

@MainActor
@Test func needingWordsSkipsTrashAndCurrentVersion() async throws {
    let store = try makeStore()
    let unread = draft("Unread", scannedAt: noon(10, 1))
    let trashed = draft("Trashed", scannedAt: noon(10, 2))
    let current = draft("Current", scannedAt: noon(10, 3))
    for scan in [unread, trashed, current] { try await store.save(scan) }
    try store.moveToTrash([trashed.id])
    store.updateSearchWords(["x"], version: 2, for: current.id)

    #expect(store.scansNeedingWords(version: 2) == [unread.id])
}

@MainActor
@Test func needingWordsIsNewestFirst() async throws {
    let store = try makeStore()
    let old = draft("Old", scannedAt: noon(10, 1))
    let middle = draft("Middle", scannedAt: noon(10, 5))
    let new = draft("New", scannedAt: noon(10, 9))
    for scan in [middle, old, new] { try await store.save(scan) }

    #expect(store.scansNeedingWords(version: 1) == [new.id, middle.id, old.id])
}

@MainActor
@Test func olderVersionNeedsWordsAgain() async throws {
    let store = try makeStore()
    let scan = draft(scannedAt: noon(10, 1))
    try await store.save(scan)
    store.updateSearchWords(["x"], version: 1, for: scan.id)
    #expect(store.scansNeedingWords(version: 1).isEmpty)

    #expect(store.scansNeedingWords(version: 2) == [scan.id])
}
