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
