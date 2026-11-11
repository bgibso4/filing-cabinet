import Core
import Foundation
import Library

/// The scans a screen may show on a given day, sorted by where they are: the library (expired ones are hidden
/// everywhere, M5) and Trash. Where each scan is comes from `Lifecycle`, under the library's lifespans.
struct LibraryShelf {
    /// How long each collection keeps its scans.
    let lifespans: CollectionLifespans
    /// Every scan in the library, newest first.
    let visible: [ScanSummary]
    /// Every scan in Trash, the soonest gone first.
    let trash: [ScanSummary]

    private let calendar: Calendar
    private let today: CalendarDay

    init(scans: [ScanSummary], lifespans: CollectionLifespans, today: CalendarDay, calendar: Calendar) {
        self.lifespans = lifespans
        self.calendar = calendar
        self.today = today
        var visible: [ScanSummary] = []
        var trash: [(scan: ScanSummary, daysLeft: Int)] = []
        for scan in scans {
            switch scan.place(lifespans: lifespans, today: today, in: calendar) {
            case .library: visible.append(scan)
            case .trash(let daysLeft, _): trash.append((scan, daysLeft))
            case .gone: break
            }
        }
        self.visible = visible.sorted { $0.scannedAt > $1.scannedAt }
        // Soonest gone first; a tie, newest first.
        self.trash =
            trash
            .sorted { ($0.daysLeft, $1.scan.scannedAt) < ($1.daysLeft, $0.scan.scannedAt) }
            .map(\.scan)
    }

    /// Scans from the last 30 days, today included: day 29 is in, day 30 is out (M15).
    var recent: [ScanSummary] {
        visible.filter { scanDay($0).days(until: today, in: calendar) < 30 }
    }

    /// The hearted scans still in the library, in Favorites' order (M3, M6). Favourites in Trash wait there.
    var favorites: [ScanSummary] {
        visible.filter(\.isFavorite).sorted(by: ScanSummary.favoritesOrder)
    }

    func `in`(_ collection: BuiltInCollection) -> [ScanSummary] {
        visible.filter { $0.collection == collection }
    }

    func count(in collection: BuiltInCollection) -> Int {
        self.in(collection).count
    }

    /// What is left of a library scan's life; `.expired` for any scan not in the library.
    func timeLeft(_ scan: ScanSummary) -> TimeLeft {
        guard case .library(let left) = place(scan) else { return .expired }
        return left
    }

    /// Days a scan in Trash has left, today included; 0 for any scan not in Trash.
    func trashDaysLeft(_ scan: ScanSummary) -> Int {
        guard case .trash(let daysLeft, _) = place(scan) else { return 0 }
        return daysLeft
    }

    /// Orange rule, judged against the scan's own span.
    func isSoon(_ scan: ScanSummary) -> Bool {
        guard case .days(let left) = timeLeft(scan), let last = scan.lastDay(lifespans: lifespans, in: calendar) else {
            return false
        }
        let span = scanDay(scan).days(until: last, in: calendar) + 1
        return TimeLeft.isSoon(daysLeft: left, spanDays: span)
    }

    private func place(_ scan: ScanSummary) -> ScanPlace {
        scan.place(lifespans: lifespans, today: today, in: calendar)
    }

    private func scanDay(_ scan: ScanSummary) -> CalendarDay {
        CalendarDay(scan.scannedAt, in: calendar)
    }
}
