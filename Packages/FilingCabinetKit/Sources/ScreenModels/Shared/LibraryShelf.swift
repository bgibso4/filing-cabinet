import Core
import Foundation
import Library

/// The scans a screen may show on a given day: expired ones are hidden everywhere (M5).
struct LibraryShelf {
    private let calendar: Calendar
    private let today: CalendarDay

    init(scans: [ScanSummary], today: CalendarDay, calendar: Calendar) {
        self.calendar = calendar
        self.today = today
        visible =
            scans
            .filter { Self.timeLeft($0, today: today, calendar: calendar) != .expired }
            .sorted { $0.scannedAt > $1.scannedAt }
    }

    /// Everything not expired, newest first.
    let visible: [ScanSummary]

    /// Scans from the last 30 days, today included: day 29 is in, day 30 is out (M15).
    var recent: [ScanSummary] {
        visible.filter { scanDay($0).days(until: today, in: calendar) < 30 }
    }

    func `in`(_ collection: BuiltInCollection) -> [ScanSummary] {
        visible.filter { $0.collection == collection }
    }

    func count(in collection: BuiltInCollection) -> Int {
        self.in(collection).count
    }

    func timeLeft(_ scan: ScanSummary) -> TimeLeft {
        Self.timeLeft(scan, today: today, calendar: calendar)
    }

    /// Orange rule, judged against the scan's own span.
    func isSoon(_ scan: ScanSummary) -> Bool {
        guard case .days(let left) = timeLeft(scan), let last = lastDay(scan) else { return false }
        let span = scanDay(scan).days(until: last, in: calendar) + 1
        return TimeLeft.isSoon(daysLeft: left, spanDays: span)
    }

    private func scanDay(_ scan: ScanSummary) -> CalendarDay {
        Self.scanDay(scan, calendar: calendar)
    }

    private func lastDay(_ scan: ScanSummary) -> CalendarDay? {
        Self.lastDay(scan, calendar: calendar)
    }

    private static func scanDay(_ scan: ScanSummary, calendar: Calendar) -> CalendarDay {
        CalendarDay(scan.scannedAt, in: calendar)
    }

    private static func lastDay(_ scan: ScanSummary, calendar: Calendar) -> CalendarDay? {
        Expiry.lastDay(
            scanDay: scanDay(scan, calendar: calendar),
            collectionLifespan: scan.collection.lifespan,
            override: scan.expiryOverride,
            in: calendar)
    }

    private static func timeLeft(_ scan: ScanSummary, today: CalendarDay, calendar: Calendar) -> TimeLeft {
        TimeLeft.on(today, lastDay: lastDay(scan, calendar: calendar), in: calendar)
    }
}
