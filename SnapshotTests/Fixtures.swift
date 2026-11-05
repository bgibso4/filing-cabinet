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

    // periphery:ignore - read by the grid snapshots (Task 16).
    static let thumbnails = FakeThumbnails(images: images(for: .home))

    // periphery:ignore - read by the viewer snapshots (Task 17).
    static let pages = FakePageImages(images: images(for: .home))

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

    // Collection.dc.html lines 219-221: the receipt stores and the ages of the 23 receipts.
    private static let stores = [
        ("Corner Market", "scan-r-corner"), ("Bluebird Café", "scan-r-bluebird"), ("City Pharmacy", "scan-r-pharmacy"),
        ("Harbor Gas", "scan-r-gas"), ("Page & Spine", "scan-r-books"), ("Northside Hardware", "scan-r-hardware"),
        ("Pizzeria Sole", "scan-r-pizza"),
    ]
    private static let receiptAges = [
        0, 1, 3, 5, 8, 12, 15, 19, 22, 26, 30, 34, 40, 45, 51, 55, 60, 66, 71, 77, 84, 86, 88,
    ]
    private static let receiptStores = [0, 1, 3, 0, 2, 5, 1, 4, 0, 3, 5, 1, 6, 0, 2, 5, 3, 1, 0, 4, 5, 0, 2]

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

    private static let homeEntries: [Entry] = {
        var entries: [Entry] = []
        for (index, age) in receiptAges.enumerated() {
            let store = stores[receiptStores[index]]
            entries.append(entry(store.0, store.1, .receipts, age))
        }
        for collection in [BuiltInCollection.wallet, .notes, .documents, .throwaways] {
            let source: [Sample]
            let count: Int
            switch collection {
            case .wallet: (source, count) = (wallet, 6)
            case .notes: (source, count) = (notes, 41)
            case .documents: (source, count) = (documents, 18)
            default: (source, count) = (throwaways, 3)
            }
            for index in 0..<count {
                let item = source[index % source.count]
                // Past the first lap the same sample repeats, one day older each time, and stays inside the lifespan.
                let age = index < source.count ? item.daysAgo : item.daysAgo + index - source.count
                entries.append(entry(item.title, item.image, collection, collection == .throwaways ? min(age, 5) : age))
            }
        }
        return entries
    }()

    private static func entry(_ title: String, _ image: String, _ collection: BuiltInCollection, _ daysAgo: Int)
        -> Entry
    {
        let scannedAt = clock.calendar.date(byAdding: .day, value: -daysAgo, to: clock.now()) ?? clock.now()
        let summary = ScanSummary(
            id: ScanID(), title: title, collection: collection, scannedAt: scannedAt, expiryOverride: nil, pageCount: 1)
        return Entry(summary: summary, image: image)
    }

    private static func entries(_ set: FixtureSet) -> [Entry] {
        switch set {
        case .home: homeEntries
        }
    }

    // MARK: Images

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
