import Core
import CoreGraphics
import Foundation
import Library
import TestSupport
import Testing

private func draft(scannedAt seconds: TimeInterval) -> ScanDraft {
    ScanDraft(
        id: ScanID(),
        title: "Corner Market",
        collection: .receipts,
        scannedAt: Date(timeIntervalSince1970: seconds),
        expiryOverride: .lifespan(.week),
        pages: [SyntheticPages.page(lines: [], size: CGSize(width: 10, height: 10))],
        searchText: nil
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
