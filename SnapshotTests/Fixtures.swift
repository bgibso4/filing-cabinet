import Core
import CoreGraphics
import Foundation
import ImageIO
import Library
import TestSupport

/// The scan sets the snapshot tests render, with the mocks' titles and ages, and the preloaded images behind them.
/// Everything is synthetic: the images are the prototype's sample scans (design/prototype/scans).
@MainActor
enum Fixtures {
    /// A named library the screens are snapshotted with.
    enum FixtureSet {
        /// Home 02-02: Wallet 6, Receipts 23, Notes 41, Documents 18, Throwaways 3 (91 in all).
        case home
        /// Home 02-04: the `home` library and four Throwaways that went to Trash on their own 2 to 5 days ago.
        case afterCleanup
        /// Trash 09-01: seven scans with 2 to 29 days left.
        case trash
        /// Trash 09-01 and three more, so the last row rests under Empty Trash.
        case fullTrash
    }

    /// Oct 12, 2026, `en_US`, in GMT so the day never depends on the machine's time zone.
    static let clock: AppClock = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let noon = DateComponents(calendar: calendar, timeZone: .gmt, year: 2026, month: 10, day: 12, hour: 12)
        return AppClock.fixed(noon.date ?? Date(timeIntervalSince1970: 0), calendar: calendar)
    }()

    static func library(_ set: FixtureSet) -> FakeLibrary {
        FakeLibrary(scans: entries(set).map(\.summary))
    }

    /// The home set's `count` newest receipts, newest first: the first tiles of its Receipts grid (the receipts are
    /// built youngest first, from `receiptAges`).
    static func newestReceipts(_ count: Int) -> [ScanID] {
        Array(homeEntries.filter { $0.image.hasPrefix("scan-r-") }.prefix(count).map(\.summary.id))
    }

    static let thumbnails = FakeThumbnails(images: allImages)
    static let pages = FakePageImages(images: allImages)

    /// ScanView.dc.html line 332: the lease, three pages, kept forever.
    static let lease = viewerScan("Lease 2026", .documents, daysAgo: 7, pageCount: 3)
    /// ScanView.dc.html line 330: added Jul 19, 2026, so 5 days left of its 90 on Oct 12.
    static let receipt = viewerScan("Corner Market", .receipts, daysAgo: 85, pageCount: 1)

    /// Trash 09-04: Coat check, opened from Trash with 5 days left. One of the `.trash` set, so it has its image.
    static var trashedCoatCheck: ScanSummary { coatCheckEntry.summary }

    /// The named sample scans (design/prototype/scans), in order; a missing one is left out.
    static func scans(_ names: String...) -> [CGImage] {
        names.compactMap(loadImage)
    }

    // MARK: Data

    /// A sample scan: its title, image and age in days.
    private struct Sample {
        let title: String
        let image: String
        let daysAgo: Int

        init(_ title: String, _ image: String, _ daysAgo: Int) {
            self.title = title
            self.image = image
            self.daysAgo = daysAgo
        }
    }

    private struct Entry {
        let summary: ScanSummary
        let image: String
    }

    // Collection.dc.html lines 219-222: the receipt stores and the ages of the 23 receipts. Tallow Electric has no
    // sample scan in design/prototype/scans, so Pizzeria Sole stands in for it.
    private static let stores = [
        ("Corner Market", "scan-r-corner"), ("Bluebird Café", "scan-r-bluebird"), ("City Pharmacy", "scan-r-pharmacy"),
        ("Harbor Gas", "scan-r-gas"), ("Page & Spine", "scan-r-books"), ("Northside Hardware", "scan-r-hardware"),
        ("Pizzeria Sole", "scan-r-pizza"),
    ]
    private static let receiptAges = [
        0, 1, 3, 5, 8, 12, 15, 19, 22, 26, 30, 34, 40, 45, 51, 55, 60, 66, 71, 77, 84, 86, 88,
    ]
    private static let receiptStores = [0, 1, 3, 0, 2, 6, 1, 4, 0, 3, 5, 1, 6, 0, 2, 6, 3, 1, 0, 4, 5, 0, 2]

    // Collection.dc.html lines 225-235: the other collections' scans.
    private static let wallet = [
        Sample("Driver’s license", "scan-license", 3), Sample("Insurance card", "scan-insurance", 12),
        Sample("Work ID", "scan-workid", 20), Sample("Gym membership", "scan-gym", 40),
        Sample("Library card", "scan-library", 95),
        Sample("Passport", "scan-passport", 160),
    ]
    private static let notes = [
        Sample("Bio 210 notes", "scan-note-bio", 2), Sample("Call with landlord", "scan-note-call", 10),
    ]
    private static let documents = [
        Sample("Lease 2026", "scan-lease", 7), Sample("Car registration", "scan-registration", 14),
        Sample("Vaccine record", "scan-vaccine", 30),
    ]
    private static let throwaways = [
        Sample("Coat check", "scan-throw-coat", 1), Sample("Parking stub", "scan-throw-park", 4),
        Sample("Valet ticket", "scan-throw-valet", 6),
    ]

    /// Throwaways come first: equal days keep this order, and the mocks put Coat check before Bluebird Café.
    private static let homeEntries: [Entry] = {
        let receipts = receiptAges.enumerated().map { index, age in
            let store = stores[receiptStores[index]]
            return entry(store.0, store.1, .receipts, age)
        }
        return laps(throwaways, .throwaways, count: 3) + receipts + laps(wallet, .wallet, count: 6)
            + laps(notes, .notes, count: 41) + laps(documents, .documents, count: 18)
    }()

    /// `count` scans from the samples. Past the first lap they repeat, older than Recent's 30 days, so Recent and the
    /// top of All Scans show each sample once, as the mocks do. Only kept-forever collections take more than one lap.
    private static func laps(_ samples: [Sample], _ collection: BuiltInCollection, count: Int) -> [Entry] {
        (0..<count).map { index in
            let sample = samples[index % samples.count]
            let daysAgo = index < samples.count ? sample.daysAgo : sample.daysAgo + 30 + index
            return entry(sample.title, sample.image, collection, daysAgo)
        }
    }

    // Trash.dc.html lines 207-215: title, image, collection and days left in Trash.
    private static let trashEntries: [Entry] = [
        trashed("Parking stub", "scan-throw-park", .throwaways, daysLeft: 2),
        coatCheckEntry,
        trashed("City Pharmacy", "scan-r-pharmacy", .receipts, daysLeft: 11),
        trashed("Bluebird Café", "scan-r-bluebird", .receipts, daysLeft: 16),
        trashed("Old wifi password", "scan-wifi", .notes, daysLeft: 24),
        trashed("Corner Market", "scan-r-corner", .throwaways, daysLeft: 27),
        trashed("Gym membership", "scan-gym", .wallet, daysLeft: 29),
    ]

    /// Throwaways keep a week, so one scanned `n` days ago entered Trash on its own `n - 7` days ago.
    private static let afterCleanupEntries: [Entry] =
        homeEntries
        + [9, 10, 11, 12].enumerated().map { index, daysAgo in
            let sample = throwaways[index % throwaways.count]
            return entry(sample.title, sample.image, .throwaways, daysAgo)
        }

    private static let coatCheckEntry = trashed("Coat check", "scan-throw-coat", .throwaways, daysLeft: 5)

    private static let fullTrashEntries: [Entry] =
        trashEntries + [
            trashed("Valet ticket", "scan-throw-valet", .throwaways, daysLeft: 29),
            trashed("Harbor Gas", "scan-r-gas", .receipts, daysLeft: 30),
            trashed("Library card", "scan-library", .wallet, daysLeft: 30),
        ]

    private static func entry(
        _ title: String,
        _ image: String,
        _ collection: BuiltInCollection,
        _ daysAgo: Int,
        trashedDay: CalendarDay? = nil
    ) -> Entry {
        let scannedAt = clock.calendar.date(byAdding: .day, value: -daysAgo, to: clock.now()) ?? clock.now()
        let summary = ScanSummary(
            id: ScanID(),
            title: title,
            collection: collection,
            scannedAt: scannedAt,
            expiryOverride: nil,
            pageCount: 1,
            trashedDay: trashedDay)
        return Entry(summary: summary, image: image)
    }

    /// Moved to Trash `30 - daysLeft` days ago, from a scan made a while before.
    private static func trashed(_ title: String, _ image: String, _ collection: BuiltInCollection, daysLeft: Int)
        -> Entry
    {
        let trashedDay = clock.today.adding(days: daysLeft - Lifecycle.trashDays, in: clock.calendar)
        return entry(title, image, collection, Lifecycle.trashDays + 1, trashedDay: trashedDay)
    }

    private static func entries(_ set: FixtureSet) -> [Entry] {
        switch set {
        case .home: homeEntries
        case .afterCleanup: afterCleanupEntries
        case .trash: trashEntries
        case .fullTrash: fullTrashEntries
        }
    }

    private static func viewerScan(
        _ title: String, _ collection: BuiltInCollection, daysAgo: Int, pageCount: Int
    ) -> ScanSummary {
        ScanSummary(
            id: ScanID(),
            title: title,
            collection: collection,
            scannedAt: clock.calendar.date(byAdding: .day, value: -daysAgo, to: clock.now()) ?? clock.now(),
            expiryOverride: nil,
            pageCount: pageCount)
    }

    // MARK: Images

    private static let allImages: [ScanID: [Int: CGImage]] = {
        var all = images(for: .home).merging(images(for: .fullTrash)) { home, _ in home }
        all[lease.id] = byIndex(scans("scan-lease", "scan-lease-p2", "scan-lease-p3"))
        all[receipt.id] = byIndex(scans("scan-r-corner"))
        return all
    }()

    private static func byIndex(_ images: [CGImage]) -> [Int: CGImage] {
        Dictionary(uniqueKeysWithValues: images.enumerated().map { ($0.offset, $0.element) })
    }

    private static func images(for set: FixtureSet) -> [ScanID: [Int: CGImage]] {
        var cache: [String: CGImage] = [:]
        var result: [ScanID: [Int: CGImage]] = [:]
        for entry in entries(set) {
            if cache[entry.image] == nil { cache[entry.image] = loadImage(entry.image) }
            if let image = cache[entry.image] { result[entry.summary.id] = [0: image] }
        }
        return result
    }

    private static func loadImage(_ name: String) -> CGImage? {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "jpg"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private final class BundleToken {}
}
