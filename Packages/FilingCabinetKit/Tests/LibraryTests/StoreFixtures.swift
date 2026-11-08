import Core
import CoreGraphics
import Foundation
import SwiftData
import TestSupport

@testable import Library

/// The store tests' calendar: Gregorian in UTC, so a day never depends on the machine's time zone.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

/// Oct 12, 2026 at noon UTC: the day every store test runs on.
let octoberTwelfth = AppClock.fixed(Date(timeIntervalSince1970: 1_791_806_400), calendar: utc)

/// A day in 2026 unless `year` says otherwise.
func day(_ month: Int, _ dayOfMonth: Int, year: Int = 2026) -> CalendarDay {
    CalendarDay(year: year, month: month, day: dayOfMonth)
}

/// Noon UTC on that day.
func noon(_ month: Int, _ dayOfMonth: Int, year: Int = 2026) -> Date {
    day(month, dayOfMonth, year: year).date(in: utc).addingTimeInterval(12 * 3600)
}

/// A fresh, empty library location under the temporary directory.
func temporaryLocation() -> LibraryLocation {
    let base = FileManager.default.temporaryDirectory.appending(path: "LibraryTests-\(UUID().uuidString)")
    return LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches"))
}

/// A small page, so encoding stays quick.
func smallPage() -> CGImage {
    SyntheticPages.page(lines: [], size: CGSize(width: 120, height: 160))
}

func draft(
    _ title: String = "City Pharmacy",
    collection: BuiltInCollection = .receipts,
    scannedAt: Date = Date(timeIntervalSince1970: 1_000),
    expiryOverride: ExpiryOverride? = nil,
    pages: Int = 1,
    searchText: String? = nil
) -> ScanDraft {
    ScanDraft(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: scannedAt,
        expiryOverride: expiryOverride,
        pages: Array(repeating: smallPage(), count: pages),
        searchText: searchText
    )
}

func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
}

/// Where the scan is today by the store's own rules.
@MainActor
func place(of id: ScanID, in library: any ScanLibrary, clock: AppClock = octoberTwelfth) -> ScanPlace? {
    guard let scan = library.scans.first(where: { $0.id == id }) else { return nil }
    let lastDay = Expiry.lastDay(
        scanDay: CalendarDay(scan.scannedAt, in: clock.calendar),
        collectionLifespan: library.lifespans[scan.collection],
        override: scan.expiryOverride,
        in: clock.calendar)
    return Lifecycle.place(lastDay: lastDay, trashedDay: scan.trashedDay, today: clock.today, in: clock.calendar)
}

/// A store on an in-memory container, living on Oct 12.
@MainActor
func makeStore(
    container: ModelContainer? = nil,
    location: LibraryLocation = temporaryLocation(),
    fileSystem: any FileSystem = LocalFileSystem(),
    persist: ((ModelContext) throws -> Void)? = nil
) throws -> ScanStore {
    ScanStore(
        container: try container ?? ScanStore.makeContainer(storeURL: nil),
        files: PageFileStore(location: location, fileSystem: fileSystem),
        clock: octoberTwelfth,
        persist: persist)
}
