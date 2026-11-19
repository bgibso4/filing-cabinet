import Core
import Foundation
import Library

/// Plans the notes that tell the person scans moved to Trash on their own (11-01 … 11-04): one a day at 9:00.
package enum CleanupNotices {
    /// The most notes iOS keeps pending for an app is 64.
    package static let defaultLimit = 64

    /// A note for each of the next `limit` days on which scans enter Trash on their own (M9). A scan counts
    /// while its day's 9:00 is still to come, it has a last day and it has no stored `trashedDay`. That includes a
    /// scan that entered Trash this morning: planning replaces every pending note, so leaving it out would take the
    /// note back when the app is opened before 9:00. With `namesScans` false (the library lock is on) no note holds
    /// a title or a kind of scan.
    package static func plan(
        scans: [ScanSummary],
        lifespans: CollectionLifespans,
        clock: AppClock,
        limit: Int = defaultLimit,
        namesScans: Bool = true
    ) -> [ScheduledNotice] {
        let calendar = clock.calendar
        // The day's year, month and day are Gregorian (as `CalendarDay` is), whatever the device calendar;
        // the zone follows the device so 9:00 is local.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let now = clock.now()
        var byEntryDay: [CalendarDay: [ScanSummary]] = [:]
        for scan in scans where scan.trashedDay == nil {
            let lastDay = scan.lastDay(lifespans: lifespans, in: calendar)
            guard let entry = Lifecycle.entryDay(lastDay: lastDay, trashedDay: nil, in: calendar),
                let fires = gregorian.date(from: fireDate(on: entry, calendar: gregorian)), fires > now
            else { continue }
            byEntryDay[entry, default: []].append(scan)
        }
        return byEntryDay.keys.sorted().prefix(limit).map { entry in
            let scans = (byEntryDay[entry] ?? []).sorted { ($0.scannedAt, $0.title) < ($1.scannedAt, $1.title) }
            return notice(for: scans, on: entry, calendar: gregorian, namesScans: namesScans)
        }
    }

    private static func notice(
        for scans: [ScanSummary], on entry: CalendarDay, calendar: Calendar, namesScans: Bool
    ) -> ScheduledNotice {
        let (title, body) = namesScans ? text(for: scans) : unnamedText(count: scans.count)
        return ScheduledNotice(
            id: "\(ScheduledNotice.idPrefix)\(entry.storageValue)",
            fireDate: fireDate(on: entry, calendar: calendar),
            title: title,
            body: body)
    }

    /// 9:00 on `entry`, in `calendar`'s zone.
    private static func fireDate(on entry: CalendarDay, calendar: Calendar) -> DateComponents {
        DateComponents(calendar: calendar, year: entry.year, month: entry.month, day: entry.day, hour: 9, minute: 0)
    }

    /// The notes while the library is locked: counts only.
    private static func unnamedText(count: Int) -> (title: String, body: String) {
        let days = Lifecycle.trashDays
        guard count > 1 else {
            return (
                String(localized: "Cleaned up 1 scan", bundle: #bundle),
                String(
                    localized: "An expired scan moved to Trash. It’s there for \(days) days if you need it.",
                    bundle: #bundle)
            )
        }
        return (
            String(localized: "Cleaned up \(count) scans", bundle: #bundle),
            String(
                localized: "Expired scans moved to Trash. They’re there for \(days) days if you need one back.",
                bundle: #bundle)
        )
    }

    private static func text(for scans: [ScanSummary]) -> (title: String, body: String) {
        let count = scans.count
        let days = Lifecycle.trashDays
        if let only = scans.first, count == 1 {
            let noun = CollectionText.noun(only.collection, count: 1)
            return (
                String(localized: "Cleaned up", bundle: #bundle),
                String(
                    localized: "Moved the \(only.title) \(noun) to Trash. It’s there for \(days) days if you need it.",
                    bundle: #bundle)
            )
        }
        guard count <= 3 else {
            return (
                String(localized: "Cleaned up \(count) scans", bundle: #bundle),
                String(
                    localized: "Expired scans moved to Trash. They’re there for \(days) days if you need one back.",
                    bundle: #bundle)
            )
        }
        let collections = Set(scans.map(\.collection))
        let noun =
            collections.count == 1
            ? CollectionText.noun(scans[0].collection, count: count) : CollectionText.scansNoun(count: count)
        let names = joined(scans.map(\.title))
        return (
            String(localized: "Cleaned up \(count) \(noun)", bundle: #bundle),
            String(
                localized: "\(names) moved to Trash. They’re there for \(days) days if you need them.",
                bundle: #bundle)
        )
    }

    /// "A, B and C" with no Oxford comma (M25), which `ListFormatter` would add in en_US.
    private static func joined(_ names: [String]) -> String {
        guard let last = names.last, names.count > 1 else { return names.first ?? "" }
        return String(
            localized: "\(names.dropLast().joined(separator: ", ")) and \(last)", bundle: #bundle)
    }
}
