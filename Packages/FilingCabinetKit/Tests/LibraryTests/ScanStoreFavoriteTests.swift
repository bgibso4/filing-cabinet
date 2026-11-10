import Core
import Foundation
import SwiftData
import Testing

@testable import Library

private struct PersistFailed: Error {}

/// Saves one scan per title, the first newest, a day apart from Oct 10 back.
@MainActor
private func save(_ titles: [String], in store: ScanStore) async throws -> [ScanID] {
    var ids: [ScanID] = []
    for (index, title) in titles.enumerated() {
        let scan = draft(title, scannedAt: noon(10, 10 - index), searchText: "\(title) text")
        try await store.save(scan)
        ids.append(scan.id)
    }
    return ids
}

/// Each scan's favourite number, in the order of `ids`; nil for a scan that isn't one or is gone.
@MainActor
private func orders(_ ids: [ScanID], in store: ScanStore) -> [Int?] {
    ids.map { id in store.scans.first { $0.id == id }?.favoriteOrder }
}

/// The favourites as every screen reads them (B11).
@MainActor
private func favorites(in store: ScanStore) -> [ScanID] {
    store.scans.filter(\.isFavorite).sorted(by: ScanSummary.favoritesOrder).map(\.id)
}

/// Gives the records these favourite numbers behind the store's back, then opens a new store on the container.
@MainActor
private func forcing(_ orders: [ScanID: Int], in container: ModelContainer) throws -> ScanStore {
    let context = container.mainContext
    for record in try context.fetch(FetchDescriptor<ScanRecord>()) {
        if let order = orders[ScanID(uuid: record.scanID)] { record.favoriteOrder = order }
    }
    try context.save()
    return try makeStore(container: container)
}

@MainActor
@Test func favoritingPutsNewOnesLast() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C"], in: store)

    try store.setFavorite(true, for: [ids[2]])
    try store.setFavorite(true, for: [ids[0]])

    #expect(orders(ids, in: store) == [1, nil, 0])
    #expect(favorites(in: store) == [ids[2], ids[0]])
}

@MainActor
@Test func favoritingSeveralKeepsTheirOrder() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C", "D"], in: store)
    try store.setFavorite(true, for: [ids[3]])

    try store.setFavorite(true, for: [ids[1], ids[0], ids[2]])

    #expect(orders(ids, in: store) == [2, 1, 3, 0])
}

@MainActor
@Test func newFavoriteSkipsNumbersHeldInTrash() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C"], in: store)
    try store.setFavorite(true, for: [ids[0], ids[1]])
    try store.moveToTrash([ids[1]])

    try store.setFavorite(true, for: [ids[2]])

    #expect(orders(ids, in: store) == [0, 1, 2])
}

@MainActor
@Test func reorderKeepsTrashedFavoritesInPlace() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C", "D"], in: store)
    try store.setFavorite(true, for: ids)
    try store.moveToTrash([ids[1]])

    // B is in Trash, so its id is ignored: the visible slots 0, 2 and 3 take D, C and A; B keeps slot 1.
    try store.reorderFavorites([ids[3], ids[1], ids[2], ids[0]])

    #expect(orders(ids, in: store) == [3, 1, 2, 0])
}

@MainActor
@Test func reorderKeepsExpiredFavoritesInPlace() async throws {
    let store = try makeStore()
    // B's own last day was Oct 11: expired, but never moved to Trash, so it isn't visible either.
    let scans = [
        draft("A", scannedAt: noon(10, 10)),
        draft("B", scannedAt: noon(10, 9), expiryOverride: .lastDay(day(10, 11))),
        draft("C", scannedAt: noon(10, 8)),
    ]
    for scan in scans { try await store.save(scan) }
    let ids = scans.map(\.id)
    try store.setFavorite(true, for: ids)
    #expect(store.scans.first { $0.id == ids[1] }?.trashedDay == nil)
    #expect(place(of: ids[1], in: store) == .trash(daysLeft: 30, entered: day(10, 12)))

    try store.reorderFavorites([ids[2], ids[0]])

    // The visible slots 0 and 2 take C and A; B keeps slot 1.
    #expect(orders(ids, in: store) == [2, 1, 0])
}

@MainActor
@Test func restoredFavoriteNeverSharesANumber() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C"], in: store)
    try store.setFavorite(true, for: [ids[0], ids[1]])
    try store.moveToTrash([ids[1]])
    try store.setFavorite(true, for: [ids[2]])

    try store.restore([ids[1]])

    #expect(orders(ids, in: store) == [0, 1, 2])
    #expect(favorites(in: store) == ids)
}

/// SplitMix64: the same steps on every run.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

@MainActor
@Test func numbersStayUniqueAcrossRandomOperations() async throws {
    let store = try makeStore()
    var ids = try await save((1...8).map { "Scan \($0)" }, in: store)
    var random = SeededGenerator(state: 2026)

    for step in 0..<500 {
        let some = Array(ids.shuffled(using: &random).prefix(Int.random(in: 1...3, using: &random)))
        let visibleFavorites = store.scans.filter { $0.isFavorite && $0.trashedDay == nil }.map(\.id)
        switch Int.random(in: 0..<6, using: &random) {
        case 0: try store.setFavorite(true, for: some)
        case 1: try store.setFavorite(false, for: some)
        case 2: try store.reorderFavorites(visibleFavorites.shuffled(using: &random) + some)
        case 3: try store.moveToTrash(some)
        case 4: try store.restore(some)
        default:
            // A deleted scan is replaced, so the run never runs out of scans.
            try await store.deleteNow([some[0]])
            ids.removeAll { $0 == some[0] }
            ids += try await save(["Replacement \(step)"], in: store)
        }

        let numbers = store.scans.compactMap(\.favoriteOrder)
        #expect(Set(numbers).count == numbers.count, "step \(step) left two favourites on one number")
    }
}

@MainActor
@Test func tiesReadInAFixedOrder() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let ids = try await save(["Newest", "Older"], in: try makeStore(container: container))
    let store = try forcing([ids[0]: 0, ids[1]: 0], in: container)

    let tied = store.scans.filter(\.isFavorite)

    // Both listed, newest first, whichever way round they come in.
    #expect(tied.sorted(by: ScanSummary.favoritesOrder).map(\.title) == ["Newest", "Older"])
    #expect(tied.reversed().sorted(by: ScanSummary.favoritesOrder).map(\.title) == ["Newest", "Older"])
}

@Test func tiesOnOneDateReadByID() {
    let date = noon(10, 1)
    let scans = (0..<2).map { _ in
        ScanSummary(
            id: ScanID(),
            title: "Tied",
            collection: .notes,
            scannedAt: date,
            expiryOverride: nil,
            pageCount: 1,
            favoriteOrder: 0)
    }

    #expect(scans.sorted(by: ScanSummary.favoritesOrder) == scans.reversed().sorted(by: ScanSummary.favoritesOrder))
}

@MainActor
@Test func nextWriteRepairsATie() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let ids = try await save(["A", "B", "C", "D"], in: try makeStore(container: container))
    let store = try forcing([ids[0]: 0, ids[1]: 0, ids[2]: 1], in: container)

    try store.setFavorite(true, for: [ids[3]])

    #expect(orders(ids, in: store) == [0, 1, 2, 3])
}

@MainActor
@Test func unfavoritingClearsOrder() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let store = try makeStore(container: container)
    let ids = try await save(["A", "B"], in: store)
    try store.setFavorite(true, for: ids)

    try store.setFavorite(false, for: [ids[0]])

    #expect(orders(ids, in: store) == [nil, 1])
    #expect(store.scans.first { $0.id == ids[0] }?.isFavorite == false)
    let stored = try ModelContext(container).fetch(FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.title)]))
    #expect(stored.map(\.favoriteOrder) == [nil, 1])
}

@MainActor
@Test func favoritingTwiceChangesNothing() async throws {
    var persists = 0
    let store = try makeStore(persist: { context in
        persists += 1
        try context.save()
    })
    let ids = try await save(["A", "B"], in: store)
    try store.setFavorite(true, for: [ids[1], ids[0]])
    let before = persists

    try store.setFavorite(true, for: [ids[0], ids[1]])
    try store.setFavorite(false, for: [ScanID()])

    #expect(orders(ids, in: store) == [1, 0])
    #expect(persists == before)
}

@MainActor
@Test func reorderSetsTheGivenOrder() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C"], in: store)
    try store.setFavorite(true, for: ids)

    try store.reorderFavorites([ids[2], ids[0], ids[1]])

    #expect(favorites(in: store) == [ids[2], ids[0], ids[1]])
    #expect(orders(ids, in: store) == [1, 2, 0])
}

@MainActor
@Test func reorderIgnoresNonFavorites() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C", "Not a favourite"], in: store)
    try store.setFavorite(true, for: Array(ids.prefix(3)))

    // B, missing from the list, keeps its place after the ones given.
    try store.reorderFavorites([ids[2], ids[3], ids[0]])

    #expect(orders(ids, in: store) == [1, 2, 0, nil])
}

@MainActor
@Test func restoreKeepsFavoriteOrder() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B", "C"], in: store)
    try store.setFavorite(true, for: ids)
    try store.moveToTrash([ids[1]])

    try store.restore([ids[1]])

    #expect(orders(ids, in: store) == [0, 1, 2])
    #expect(favorites(in: store) == ids)
}

@MainActor
@Test func moveToTrashKeepsFavoriteOrder() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B"], in: store)
    try store.setFavorite(true, for: ids)

    try store.moveToTrash([ids[0]])

    #expect(store.scans.first { $0.id == ids[0] }?.trashedDay == day(10, 12))
    #expect(orders(ids, in: store) == [0, 1])
}

@MainActor
@Test func deleteNowDropsTheFavorite() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let store = try makeStore(container: container)
    let ids = try await save(["A", "B"], in: store)
    try store.setFavorite(true, for: ids)

    try await store.deleteNow([ids[0]])

    #expect(favorites(in: store) == [ids[1]])
    #expect(try ModelContext(container).fetch(FetchDescriptor<ScanRecord>()).map(\.favoriteOrder) == [1])
}

@MainActor
@Test func failedPersistChangesNothing() async throws {
    var failPersist = false
    let container = try ScanStore.makeContainer(storeURL: nil)
    let store = try makeStore(
        container: container,
        persist: { context in
            if failPersist { throw PersistFailed() }
            try context.save()
        })
    let ids = try await save(["A", "B", "C"], in: store)
    try store.setFavorite(true, for: [ids[0], ids[1]])
    failPersist = true

    #expect(throws: LibraryError.writeFailed) { try store.setFavorite(true, for: [ids[2]]) }
    #expect(throws: LibraryError.writeFailed) { try store.setFavorite(false, for: [ids[0]]) }
    #expect(throws: LibraryError.writeFailed) { try store.reorderFavorites([ids[1], ids[0]]) }

    #expect(orders(ids, in: store) == [0, 1, nil])
    let stored = try container.mainContext.fetch(FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.title)]))
    #expect(stored.map(\.favoriteOrder) == [0, 1, nil])
    #expect(!container.mainContext.hasChanges)
}

@MainActor
@Test func searchTextsReturnsEveryScansText() async throws {
    let store = try makeStore()
    let ids = try await save(["A", "B"], in: store)
    try store.moveToTrash([ids[1]])

    #expect(store.searchTexts() == [ids[0]: "A text", ids[1]: "B text"])
    #expect(store.searchText(for: ids[1]) == "B text")
    #expect(store.searchText(for: ScanID()) == nil)
}
