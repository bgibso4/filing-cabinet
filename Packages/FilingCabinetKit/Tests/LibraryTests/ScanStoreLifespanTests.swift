import Core
import Foundation
import SwiftData
import Testing

@testable import Library

@MainActor
@Test func lengtheningKeepsTrashedScansInTrash() async throws {
    let store = try makeStore()
    // A week from Oct 3: last day Oct 9, so it entered Trash on Oct 10 without a stored day.
    let throwaway = draft("Parking stub", collection: .throwaways, scannedAt: noon(10, 3))
    try await store.save(throwaway)
    #expect(place(of: throwaway.id, in: store) == .trash(daysLeft: 28, entered: day(10, 10)))

    try store.setLifespan(.year, for: .throwaways)

    #expect(store.lifespans[.throwaways] == .year)
    #expect(store.scans.first?.trashedDay == day(10, 10))
    #expect(place(of: throwaway.id, in: store) == .trash(daysLeft: 28, entered: day(10, 10)))
}

@MainActor
@Test func anotherCollectionsChangeLeavesNaturalTrashUnmarked() async throws {
    let store = try makeStore()
    // A week from Oct 3: in Trash on its own since Oct 10. A Receipts change doesn't move that day, so nothing is
    // stored and the scan still counts as having entered on its own (M4, M9).
    let throwaway = draft("Parking stub", collection: .throwaways, scannedAt: noon(10, 3))
    try await store.save(throwaway)

    try store.setLifespan(.month, for: .receipts)

    #expect(store.scans.first?.trashedDay == nil)
    #expect(place(of: throwaway.id, in: store) == .trash(daysLeft: 28, entered: day(10, 10)))
}

@MainActor
@Test func shorteningSendsOldScansToTrashToday() async throws {
    let store = try makeStore()
    let old = draft("Corner Market", scannedAt: noon(9, 2))
    let recent = draft("City Pharmacy", scannedAt: noon(10, 2))
    for scan in [old, recent] { try await store.save(scan) }

    try store.setLifespan(.month, for: .receipts)

    #expect(place(of: old.id, in: store) == .trash(daysLeft: 30, entered: day(10, 12)))
    #expect(store.scans.first { $0.id == old.id }?.trashedDay == day(10, 12))
    #expect(place(of: recent.id, in: store) == .library(.days(20)))
    #expect(store.scans.first { $0.id == recent.id }?.trashedDay == nil)
}

@MainActor
@Test func shorteningSkipsCustomExpiries() async throws {
    let store = try makeStore()
    let custom = draft("Warranty receipt", scannedAt: noon(9, 2), expiryOverride: .lifespan(.year))
    try await store.save(custom)

    try store.setLifespan(.month, for: .receipts)

    #expect(store.scans.first?.trashedDay == nil)
    #expect(
        place(of: custom.id, in: store) == .library(TimeLeft.on(day(10, 12), lastDay: day(9, 1, year: 2027), in: utc)))
}

@MainActor
@Test func countMatchesWhatShorteningDoes() async throws {
    let store = try makeStore()
    let expiring = [draft(scannedAt: noon(9, 2)), draft(scannedAt: noon(8, 1))]
    let others = [
        draft(scannedAt: noon(10, 2)),
        draft(scannedAt: noon(8, 1), expiryOverride: .lifespan(.year)),
        // Three months from Jul 1: in Trash since Sep 29.
        draft(scannedAt: noon(7, 1)),
        draft(collection: .documents, scannedAt: noon(8, 1)),
    ]
    for scan in expiring + others { try await store.save(scan) }

    let count = store.scansExpiring(ifLifespan: .month, for: .receipts)
    try store.setLifespan(.month, for: .receipts)

    #expect(count == 2)
    #expect(Set(store.scans.filter { $0.trashedDay == day(10, 12) }.map(\.id)) == Set(expiring.map(\.id)))
    #expect(store.scans.first { $0.id == others[2].id }?.trashedDay == day(9, 29))
}

@MainActor
@Test func lifespansSurviveReopening() throws {
    let location = temporaryLocation()
    try FileManager.default.createDirectory(at: location.root, withIntermediateDirectories: true)
    let files = PageFileStore(location: location, fileSystem: LocalFileSystem())
    do {
        let store = ScanStore(
            container: try ScanStore.makeContainer(storeURL: location.storeURL), files: files, clock: octoberTwelfth)
        try store.setLifespan(.week, for: .receipts)
        try store.setLifespan(.year, for: .receipts)
        try store.setLifespan(.month, for: .notes)
    }

    let reopened = ScanStore(
        container: try ScanStore.makeContainer(storeURL: location.storeURL), files: files, clock: octoberTwelfth)

    let expected = CollectionLifespans.defaults.setting(.year, for: .receipts).setting(.month, for: .notes)
    #expect(reopened.lifespans == expected)
}

@MainActor
@Test func failedLifespanChangeChangesNothing() async throws {
    var failPersist = false
    let store = try makeStore(persist: { context in
        if failPersist { throw CocoaError(.fileWriteUnknown) }
        try context.save()
    })
    let old = draft(scannedAt: noon(9, 2))
    try await store.save(old)
    failPersist = true

    #expect(throws: LibraryError.writeFailed) {
        try store.setLifespan(.month, for: .receipts)
    }

    #expect(store.lifespans == .defaults)
    #expect(store.scans.first?.trashedDay == nil)
    #expect(place(of: old.id, in: store) == .library(.days(50)))
}
