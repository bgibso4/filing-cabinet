import Core
import Foundation
import SwiftData
import Testing

@testable import Library

private struct PersistFailed: Error {}

/// Jul 19: 85 days before Oct 12, so a receipt has 5 days left of its 90 (ScanView.dc.html line 330).
private let julyNineteenth = noon(7, 19)

@MainActor
@Test func renameChangesOnlyTheTitle() async throws {
    let container = try ScanStore.makeContainer(storeURL: nil)
    let store = try makeStore(container: container)
    let scan = draft("Corner Market", scannedAt: julyNineteenth, expiryOverride: .lifespan(.year))
    try await store.save(scan)
    let before = try #require(store.scans.first)

    try store.rename(scan.id, to: "Corner Market · AA batteries")

    let after = try #require(store.scans.first)
    #expect(after.title == "Corner Market · AA batteries")
    #expect(after.collection == before.collection)
    #expect(after.scannedAt == before.scannedAt)
    #expect(after.expiryOverride == before.expiryOverride)
    #expect(after.trashedDay == nil)
    let persisted = try ModelContext(container).fetch(FetchDescriptor<ScanRecord>())
    #expect(persisted.map(\.title) == ["Corner Market · AA batteries"])
}

@MainActor
@Test func moveKeepsACustomExpiry() async throws {
    let store = try makeStore()
    let lastDay = ExpiryOverride.lastDay(day(3, 3, year: 2027))
    let scan = draft(collection: .receipts, scannedAt: julyNineteenth, expiryOverride: lastDay)
    try await store.save(scan)

    try store.move(scan.id, to: .throwaways)

    #expect(store.scans.first?.collection == .throwaways)
    #expect(store.scans.first?.expiryOverride == lastDay)
    #expect(store.scans.first?.trashedDay == nil)
    #expect(place(of: scan.id, in: store) == .library(.days(143)))
}

@MainActor
@Test func moveFollowsTheNewDefault() async throws {
    let store = try makeStore()
    let scan = draft(collection: .receipts, scannedAt: julyNineteenth)
    try await store.save(scan)

    try store.move(scan.id, to: .documents)

    #expect(store.scans.first?.collection == .documents)
    #expect(store.scans.first?.expiryOverride == nil)
    #expect(place(of: scan.id, in: store) == .library(.forever))
}

@MainActor
@Test func movingToAShorterCollectionTrashesTodayWithThirtyDays() async throws {
    let store = try makeStore()
    let scan = draft(collection: .receipts, scannedAt: julyNineteenth)
    try await store.save(scan)

    try store.move(scan.id, to: .throwaways)

    #expect(store.scans.first?.trashedDay == day(10, 12))
    #expect(place(of: scan.id, in: store) == .trash(daysLeft: 30, entered: day(10, 12)))
}

/// M1: a scan already in Trash stays there with its entry day, whatever its new collection keeps.
@MainActor
@Test func movingAScanInTrashKeepsItsEntryDay() async throws {
    let store = try makeStore()
    // A Throwaway scanned Oct 1 lasts through Oct 7 and entered Trash on Oct 8.
    let scan = draft(collection: .throwaways, scannedAt: noon(10, 1))
    try await store.save(scan)

    try store.move(scan.id, to: .documents)

    #expect(store.scans.first?.trashedDay == day(10, 8))
    #expect(place(of: scan.id, in: store) == .trash(daysLeft: 26, entered: day(10, 8)))
}

@MainActor
@Test func setExpiryStoresTheOverride() async throws {
    let store = try makeStore()
    let scan = draft(collection: .receipts, scannedAt: julyNineteenth)
    try await store.save(scan)

    try store.setExpiry(.lifespan(.year), for: scan.id)
    #expect(store.scans.first?.expiryOverride == .lifespan(.year))

    try store.setExpiry(.lastDay(day(3, 3, year: 2027)), for: scan.id)
    #expect(store.scans.first?.expiryOverride == .lastDay(day(3, 3, year: 2027)))

    try store.setExpiry(nil, for: scan.id)
    #expect(store.scans.first?.expiryOverride == nil)
    #expect(store.scans.first?.collection == .receipts)
}

@MainActor
@Test func expiryThatHasPassedTrashesTodayWithThirtyDays() async throws {
    let store = try makeStore()
    let scan = draft(collection: .receipts, scannedAt: julyNineteenth)
    try await store.save(scan)

    // A week from Jul 19 ended Jul 25: without M1 the scan would skip Trash altogether.
    try store.setExpiry(.lifespan(.week), for: scan.id)

    #expect(store.scans.first?.expiryOverride == .lifespan(.week))
    #expect(store.scans.first?.trashedDay == day(10, 12))
    #expect(place(of: scan.id, in: store) == .trash(daysLeft: 30, entered: day(10, 12)))
}

/// M1: a scan already in Trash stays there with its entry day, whatever its new expiry says.
@MainActor
@Test func changingTheExpiryOfAScanInTrashKeepsItsEntryDay() async throws {
    let store = try makeStore()
    // A Throwaway scanned Oct 1 lasts through Oct 7 and entered Trash on Oct 8.
    let scan = draft(collection: .throwaways, scannedAt: noon(10, 1))
    try await store.save(scan)

    try store.setExpiry(.lifespan(.forever), for: scan.id)

    #expect(store.scans.first?.trashedDay == day(10, 8))
    #expect(place(of: scan.id, in: store) == .trash(daysLeft: 26, entered: day(10, 8)))
}

@MainActor
@Test func failedPersistRollsBack() async throws {
    var failPersist = false
    let container = try ScanStore.makeContainer(storeURL: nil)
    let store = try makeStore(
        container: container,
        persist: { context in
            if failPersist { throw PersistFailed() }
            try context.save()
        })
    let scan = draft("Corner Market")
    try await store.save(scan)
    failPersist = true

    #expect(throws: LibraryError.writeFailed) {
        try store.rename(scan.id, to: "Renamed")
    }

    #expect(store.scans.map(\.title) == ["Corner Market"])
    #expect(try container.mainContext.fetch(FetchDescriptor<ScanRecord>()).map(\.title) == ["Corner Market"])
    #expect(!container.mainContext.hasChanges)
}

@MainActor
@Test func storeStartsOnTheDefaultLifespans() throws {
    #expect(try makeStore().lifespans == .defaults)
}
