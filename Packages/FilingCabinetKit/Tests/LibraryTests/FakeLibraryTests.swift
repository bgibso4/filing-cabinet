import Core
import CoreGraphics
import Foundation
import Library
import TestSupport
import Testing

private func draft(scannedAt seconds: TimeInterval, searchWords: [String] = [], version: Int? = nil) -> ScanDraft {
    ScanDraft(
        id: ScanID(),
        title: "Corner Market",
        collection: .receipts,
        scannedAt: Date(timeIntervalSince1970: seconds),
        expiryOverride: .lifespan(.week),
        pages: [SyntheticPages.page(lines: [], size: CGSize(width: 10, height: 10))],
        searchText: nil,
        searchWords: searchWords,
        searchWordsVersion: version
    )
}

private func summary(_ title: String, _ collection: BuiltInCollection, scannedAt: Date) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: scannedAt,
        expiryOverride: nil,
        pageCount: 1
    )
}

@MainActor
@Test func fakeLibraryKeepsScansNewestFirstLikeTheStore() async throws {
    let fake = FakeLibrary()
    let library: any ScanLibrary = fake
    let older = draft(scannedAt: 1_000)
    let newer = draft(scannedAt: 2_000)

    try await library.save(older)
    try await library.save(newer)
    library.updateSearchText("corner market", for: older.id)

    #expect(library.scans.map(\.id) == [newer.id, older.id])
    #expect(library.scans.last?.expiryOverride == .lifespan(.week))
    #expect(fake.saved.map(\.id) == [older.id, newer.id])
    #expect(fake.searchTextUpdates == [older.id: "corner market"])
}

@MainActor
@Test func fakeLibraryFailsTheNextSaveOnlyAndKeepsNothing() async throws {
    let fake = FakeLibrary()
    fake.failNextSave = .diskFull
    let failed = draft(scannedAt: 1_000)

    await #expect(throws: LibraryError.diskFull) {
        try await fake.save(failed)
    }
    #expect(fake.scans.isEmpty)
    #expect(fake.saved.isEmpty)

    let next = draft(scannedAt: 2_000)
    try await fake.save(next)
    #expect(fake.scans.map(\.id) == [next.id])
}

@MainActor
@Test func fakeLibraryDropsSearchTextForAnUnsavedScanLikeTheStore() {
    let fake = FakeLibrary()
    fake.updateSearchText("corner market", for: ScanID())
    #expect(fake.searchTextUpdates.isEmpty)
    #expect(fake.searchTextRevision == 0)
}

@MainActor
@Test func fakeFollowsTheSameTrashRules() throws {
    // A receipt scanned Jul 19, moved to Throwaways on Oct 12, as in the store's test.
    let receipt = summary("Corner Market", .receipts, scannedAt: noon(7, 19))
    let library: any ScanLibrary = FakeLibrary(scans: [receipt], clock: octoberTwelfth)

    try library.move(receipt.id, to: .throwaways)

    #expect(library.scans.first?.collection == .throwaways)
    #expect(library.scans.first?.trashedDay == day(10, 12))
    #expect(place(of: receipt.id, in: library) == .trash(daysLeft: 30, entered: day(10, 12)))
}

@MainActor
@Test func fakeTrashesAPassedExpiryLikeTheStore() throws {
    // A receipt scanned Jul 19 given a week on Oct 12, as in the store's test.
    let receipt = summary("Corner Market", .receipts, scannedAt: noon(7, 19))
    let library = FakeLibrary(scans: [receipt], clock: octoberTwelfth)

    try library.setExpiry(.lifespan(.week), for: receipt.id)

    #expect(library.scans.first?.expiryOverride == .lifespan(.week))
    #expect(library.scans.first?.trashedDay == day(10, 12))
    #expect(place(of: receipt.id, in: library) == .trash(daysLeft: 30, entered: day(10, 12)))
}

@MainActor
@Test func fakeEditsLikeTheStore() async throws {
    let scans = (0..<3).map { summary("Scan \($0)", .documents, scannedAt: noon(10, 10 - $0)) }
    let library = FakeLibrary(scans: scans, clock: octoberTwelfth)

    try library.rename(scans[0].id, to: "Lease 2026")
    try library.setExpiry(.lifespan(.year), for: scans[0].id)
    try library.moveToTrash([scans[1].id, scans[2].id])
    try library.restore([scans[2].id])
    try await library.deleteNow([scans[1].id])

    #expect(library.lifespans == .defaults)
    #expect(library.scans.map(\.id) == [scans[0].id, scans[2].id])
    #expect(library.scans[0].title == "Lease 2026")
    #expect(library.scans[0].expiryOverride == .lifespan(.year))
    #expect(library.scans[1].trashedDay == nil)
    #expect(library.scans[1].expiryOverride == .lifespan(.forever))
}

@MainActor
@Test func fakeFailsTheNextEditOnlyAndChangesNothing() throws {
    let scan = summary("Corner Market", .receipts, scannedAt: noon(10, 1))
    let library = FakeLibrary(scans: [scan], clock: octoberTwelfth)
    library.failNextEdit = .writeFailed

    #expect(throws: LibraryError.writeFailed) {
        try library.rename(scan.id, to: "Renamed")
    }
    #expect(library.scans.map(\.title) == ["Corner Market"])

    try library.rename(scan.id, to: "Renamed")
    #expect(library.scans.map(\.title) == ["Renamed"])
}

@MainActor
@Test func fakeChangesLifespansLikeTheStore() throws {
    // As in the store's tests: a Throwaway in Trash since Oct 10, receipts scanned Sep 2 and Oct 2.
    let throwaway = summary("Parking stub", .throwaways, scannedAt: noon(10, 3))
    let old = summary("Corner Market", .receipts, scannedAt: noon(9, 2))
    let recent = summary("City Pharmacy", .receipts, scannedAt: noon(10, 2))
    let library = FakeLibrary(scans: [throwaway, old, recent], clock: octoberTwelfth)

    #expect(library.scansExpiring(ifLifespan: .month, for: .receipts) == 1)
    try library.setLifespan(.month, for: .receipts)
    try library.setLifespan(.year, for: .throwaways)

    #expect(
        library.lifespans
            == CollectionLifespans.defaults.setting(.month, for: .receipts).setting(.year, for: .throwaways))
    #expect(place(of: throwaway.id, in: library) == .trash(daysLeft: 28, entered: day(10, 10)))
    #expect(place(of: old.id, in: library) == .trash(daysLeft: 30, entered: day(10, 12)))
    #expect(place(of: recent.id, in: library) == .library(.days(20)))
}

@MainActor
@Test func fakeEmptiesTrashLikeTheStore() async throws {
    let moved = summary("Lease 2025", .documents, scannedAt: noon(10, 1))
    let expired = summary("Coat check", .throwaways, scannedAt: noon(10, 3))
    let kept = summary("Lease 2026", .documents, scannedAt: noon(10, 2))
    let library = FakeLibrary(scans: [moved, expired, kept], clock: octoberTwelfth)
    try library.moveToTrash([moved.id])

    #expect(try await library.emptyTrash() == 2)
    #expect(library.scans.map(\.id) == [kept.id])
}

/// Scans a day apart from Oct 10 back, the first newest.
private func dated(_ titles: [String]) -> [ScanSummary] {
    titles.enumerated().map { summary($1, .notes, scannedAt: noon(10, 10 - $0)) }
}

@MainActor
private func orders(_ scans: [ScanSummary], in library: FakeLibrary) -> [Int?] {
    scans.map { scan in library.scans.first { $0.id == scan.id }?.favoriteOrder }
}

@MainActor
@Test func fakeFavoritingPutsNewOnesLast() throws {
    let scans = dated(["A", "B", "C"])
    let library = FakeLibrary(scans: scans, clock: octoberTwelfth)

    try library.setFavorite(true, for: [scans[2].id])
    try library.setFavorite(true, for: [scans[0].id])

    #expect(orders(scans, in: library) == [1, nil, 0])
}

@MainActor
@Test func fakeFavoritingSeveralKeepsTheirOrder() throws {
    let scans = dated(["A", "B", "C", "D"])
    let library = FakeLibrary(scans: scans, clock: octoberTwelfth)
    try library.setFavorite(true, for: [scans[3].id])

    try library.setFavorite(true, for: [scans[1].id, scans[0].id, scans[2].id])

    #expect(orders(scans, in: library) == [2, 1, 3, 0])
}

@MainActor
@Test func fakeNewFavoriteSkipsNumbersHeldInTrash() throws {
    let scans = dated(["A", "B", "C"])
    let library = FakeLibrary(scans: scans, clock: octoberTwelfth)
    try library.setFavorite(true, for: [scans[0].id, scans[1].id])
    try library.moveToTrash([scans[1].id])

    try library.setFavorite(true, for: [scans[2].id])

    #expect(orders(scans, in: library) == [0, 1, 2])
}

@MainActor
@Test func fakeReorderKeepsTrashedFavoritesInPlace() throws {
    let scans = dated(["A", "B", "C", "D"])
    let library = FakeLibrary(scans: scans, clock: octoberTwelfth)
    try library.setFavorite(true, for: scans.map(\.id))
    try library.moveToTrash([scans[1].id])

    try library.reorderFavorites([scans[3].id, scans[2].id, scans[0].id])

    #expect(orders(scans, in: library) == [3, 1, 2, 0])
}

@MainActor
@Test func fakeKeepsSearchTextLikeTheStore() async throws {
    let fake = FakeLibrary()
    let scan = draft(scannedAt: 1_000)
    try await fake.save(scan)

    fake.updateSearchText("corner market", for: scan.id)

    #expect(fake.searchTextRevision == 1)
    #expect(fake.searchTexts() == [scan.id: "corner market"])
    #expect(fake.searchText(for: scan.id) == "corner market")
    #expect(fake.searchText(for: ScanID()) == nil)
}

@MainActor
@Test func fakeLibraryKeepsADraftsWordsAndUpdatesThem() async throws {
    let fake = FakeLibrary()
    let library: any ScanLibrary = fake
    let scan = draft(scannedAt: 1_791_720_000, searchWords: ["ID"], version: 1)
    try await library.save(scan)
    #expect(library.searchWords()[scan.id] == ["ID"])
    #expect(library.scansNeedingWords(version: 1).isEmpty)
    #expect(library.scansNeedingWords(version: 2) == [scan.id])

    let before = library.searchTextRevision
    library.updateSearchWords(["card", "licence"], version: 2, for: scan.id)

    #expect(library.searchWords()[scan.id] == ["card", "licence"])
    #expect(library.searchTextRevision == before + 1)
    #expect(library.scansNeedingWords(version: 2).isEmpty)
}

@MainActor
@Test func fakeLibraryIgnoresWordsForAMissingScan() {
    let library: any ScanLibrary = FakeLibrary()

    library.updateSearchWords(["ghost"], version: 1, for: ScanID())

    #expect(library.searchTextRevision == 0)
    #expect(library.searchWords().isEmpty)
}
