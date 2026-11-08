import Core
import Foundation
import Library

/// Plans the notes that tell the person scans moved to Trash on their own (11-01 … 11-04): one a day at 9:00.
package enum CleanupNotices {
    /// The most notes iOS keeps pending for an app is 64.
    package static let defaultLimit = 64

    /// A note for each of the next `limit` days on which scans enter Trash on their own (M9). A scan counts
    /// only while it is in the library, has a last day and has no stored `trashedDay`.
    package static func plan(
        scans: [ScanSummary],
        lifespans: CollectionLifespans,
        today: CalendarDay,
        clock: AppClock,
        limit: Int = defaultLimit
    ) -> [ScheduledNotice] {
        let calendar = clock.calendar
        // The day's year, month and day are Gregorian (as `CalendarDay` is), whatever the device calendar;
        // the zone follows the device so 9:00 is local.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        var byEntryDay: [CalendarDay: [ScanSummary]] = [:]
        for scan in scans where scan.trashedDay == nil {
            let lastDay = scan.lastDay(lifespans: lifespans, in: calendar)
            guard case .library = scan.place(lifespans: lifespans, today: today, in: calendar),
                let entry = Lifecycle.entryDay(lastDay: lastDay, trashedDay: nil, in: calendar)
            else { continue }
            byEntryDay[entry, default: []].append(scan)
        }
        return byEntryDay.keys.sorted().prefix(limit).map { entry in
            let scans = (byEntryDay[entry] ?? []).sorted { ($0.scannedAt, $0.title) < ($1.scannedAt, $1.title) }
            return notice(for: scans, on: entry, calendar: gregorian)
        }
    }

    private static func notice(for scans: [ScanSummary], on entry: CalendarDay, calendar: Calendar) -> ScheduledNotice {
        let (title, body) = text(for: scans)
        return ScheduledNotice(
            id: "\(ScheduledNotice.idPrefix)\(entry.storageValue)",
            fireDate: DateComponents(
                calendar: calendar, year: entry.year, month: entry.month, day: entry.day, hour: 9, minute: 0),
            title: title,
            body: body)
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
