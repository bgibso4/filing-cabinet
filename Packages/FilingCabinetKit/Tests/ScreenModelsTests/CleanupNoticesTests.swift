import Core
import Foundation
import Library
import Testing

@testable import ScreenModels

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

private let today = CalendarDay(year: 2026, month: 10, day: 12)
private let noon = today.date(in: utc).addingTimeInterval(12 * 3600)
private let clock = AppClock.fixed(noon, calendar: utc)

private func day(_ offset: Int) -> CalendarDay { today.adding(days: offset, in: utc) }

/// A scan that enters Trash on its own on `entry` (its last day is the day before), scanned `scannedDaysAgo` days ago.
private func expiring(
    _ title: String,
    _ collection: BuiltInCollection = .receipts,
    entering entry: CalendarDay,
    scannedDaysAgo: Int = 10,
    trashedDay: CalendarDay? = nil,
    override: ExpiryOverride? = nil
) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: noon.addingTimeInterval(-Double(scannedDaysAgo) * 86_400),
        expiryOverride: override ?? .lastDay(entry.adding(days: -1, in: utc)),
        pageCount: 1,
        trashedDay: trashedDay)
}

private func plan(
    _ scans: [ScanSummary], lifespans: CollectionLifespans = .defaults, clock: AppClock = clock
) -> [ScheduledNotice] {
    CleanupNotices.plan(scans: scans, lifespans: lifespans, today: today, clock: clock)
}

@Test func oneScanNamesItWithItsNoun() {
    let notices = plan([expiring("City Pharmacy", entering: day(3))])
    #expect(notices.count == 1)
    #expect(notices[0].title == "Cleaned up")
    #expect(
        notices[0].body == "Moved the City Pharmacy receipt to Trash. It’s there for 30 days if you need it.")
}

@Test func threeReceiptsAreCountedByNoun() {
    let entry = day(3)
    let notices = plan([
        expiring("City Pharmacy", entering: entry, scannedDaysAgo: 30),
        expiring("Bluebird Café", entering: entry, scannedDaysAgo: 20),
        expiring("Corner Market", entering: entry, scannedDaysAgo: 10),
    ])
    #expect(notices[0].title == "Cleaned up 3 receipts")
    #expect(
        notices[0].body
            == "City Pharmacy, Bluebird Café and Corner Market moved to Trash. They’re there for 30 days if you need them."
    )
}

@Test func twoScansJoinWithAnd() {
    let entry = day(3)
    let notices = plan([
        expiring("City Pharmacy", entering: entry, scannedDaysAgo: 30),
        expiring("Corner Market", entering: entry, scannedDaysAgo: 10),
    ])
    #expect(notices[0].title == "Cleaned up 2 receipts")
    #expect(notices[0].body.hasPrefix("City Pharmacy and Corner Market moved to Trash."))
}

@Test func mixedAreCalledScans() {
    let entry = day(3)
    let notices = plan([
        expiring("Parking stub", .throwaways, entering: entry, scannedDaysAgo: 30),
        expiring("Coat check", .throwaways, entering: entry, scannedDaysAgo: 20),
        expiring("City Pharmacy", .receipts, entering: entry, scannedDaysAgo: 10),
    ])
    #expect(notices[0].title == "Cleaned up 3 scans")
    #expect(
        notices[0].body
            == "Parking stub, Coat check and City Pharmacy moved to Trash. They’re there for 30 days if you need them."
    )
}

@Test func fourOrMoreShowOnlyTheCount() {
    let entry = day(3)
    let scans = (1...8).map { expiring("Receipt \($0)", entering: entry) }
    let notices = plan(scans)
    #expect(notices[0].title == "Cleaned up 8 scans")
    #expect(notices[0].body == "Expired scans moved to Trash. They’re there for 30 days if you need one back.")
}

@Test func oneNotePerDayAtNine() {
    let notices = plan([
        expiring("B", entering: day(5)),
        expiring("A", entering: day(2)),
        expiring("C", entering: day(5)),
    ])
    #expect(notices.count == 2)
    #expect(notices[0].id == "\(ScheduledNotice.idPrefix)20261014")
    #expect(notices[1].id == "\(ScheduledNotice.idPrefix)20261017")
    #expect(notices[0].fireDate.year == 2026 && notices[0].fireDate.month == 10 && notices[0].fireDate.day == 14)
    #expect(notices[0].fireDate.hour == 9 && notices[0].fireDate.minute == 0)
}

@Test func onlyTheNext64DaysAreScheduled() {
    let scans = (1...70).map { expiring("Scan \($0)", entering: day($0)) }
    let notices = plan(scans)
    #expect(notices.count == 64)
    #expect(notices.first?.id == "\(ScheduledNotice.idPrefix)\(day(1).storageValue)")
    #expect(notices.last?.id == "\(ScheduledNotice.idPrefix)\(day(64).storageValue)")
}

@Test func renamedScanIsNamedByItsNewTitle() {
    var scan = expiring("Scan 14", entering: day(3))
    scan.title = "Dentist bill"
    #expect(plan([scan])[0].body.hasPrefix("Moved the Dentist bill receipt to Trash."))
}

@Test func manualTrashAndRestoredScansAreNotAnnounced() {
    let trashed = expiring("Moved by hand", entering: day(3), trashedDay: day(-1))
    // Restore sets the forever override and clears the Trash day.
    let restored = expiring("Restored", entering: day(3), override: .lifespan(.forever))
    #expect(plan([trashed, restored]).isEmpty)
}

@Test func aScanThatEntersTrashTodayIsNotAnnounced() {
    #expect(plan([expiring("Already out", entering: today)]).isEmpty)
}

@Test func fireDateIsGregorianAtLocalNineWhateverTheDeviceCalendar() {
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = utc.timeZone
    let notices = plan([expiring("City Pharmacy", entering: day(3))], clock: .fixed(noon, calendar: buddhist))
    #expect(notices[0].fireDate.calendar?.identifier == .gregorian)
    #expect(notices[0].fireDate.calendar?.timeZone == utc.timeZone)
    #expect(notices[0].fireDate.year == 2026)
}

@Test func foreverScansNeverNotify() {
    let wallet = expiring("Licence", .wallet, entering: day(3), override: .lifespan(.forever))
    let byDefault = ScanSummary(
        id: ScanID(),
        title: "Passport",
        collection: .wallet,
        scannedAt: noon,
        expiryOverride: nil,
        pageCount: 1)
    #expect(plan([wallet, byDefault]).isEmpty)
}

@Test func customLifespansMoveTheDay() {
    let scan = ScanSummary(
        id: ScanID(),
        title: "City Pharmacy",
        collection: .receipts,
        scannedAt: noon,
        expiryOverride: nil,
        pageCount: 1)
    // Scanned today, a 1 week lifespan: last day is today + 6, so it enters Trash on today + 7.
    let week = plan([scan], lifespans: CollectionLifespans.defaults.setting(.week, for: .receipts))
    #expect(week.map(\.id) == ["\(ScheduledNotice.idPrefix)\(day(7).storageValue)"])
    let month = plan([scan], lifespans: CollectionLifespans.defaults.setting(.month, for: .receipts))
    #expect(month.map(\.id) == ["\(ScheduledNotice.idPrefix)\(day(30).storageValue)"])
}
