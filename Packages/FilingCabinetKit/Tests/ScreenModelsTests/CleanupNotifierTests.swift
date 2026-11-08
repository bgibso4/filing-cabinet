import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
private let noon = oct12.date(in: utc).addingTimeInterval(12 * 3600)

/// A receipt that enters Trash on its own `daysAhead` days after Oct 12 (its last day is the day before).
private func expiring(_ title: String, daysAhead: Int) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: .receipts,
        scannedAt: noon.addingTimeInterval(-10 * 86_400),
        expiryOverride: .lastDay(oct12.adding(days: daysAhead - 1, in: utc)),
        pageCount: 1)
}

/// A notifier running over a fake library, a movable clock and fresh preferences.
@MainActor
private struct NotifierHarness {
    let now = MovableNow(noon)
    let library: FakeLibrary
    let today: Today
    let preferences: AppPreferences
    let center: FakeNotificationCenter
    let notifier: CleanupNotifier
    private let fresh: FreshDefaults
    private let running: Task<Void, Never>

    init(_ scans: [ScanSummary], authorization: NotificationAuthorization = .authorized) throws {
        let now = now
        let clock = AppClock(now: { now.now }, calendar: utc, locale: Locale(identifier: "en_US"))
        fresh = try FreshDefaults()
        library = FakeLibrary(scans: scans, clock: clock)
        today = Today(clock: clock)
        preferences = AppPreferences(defaults: fresh.defaults)
        center = FakeNotificationCenter(authorization: authorization)
        let notifier = CleanupNotifier(
            library: library, today: today, preferences: preferences, center: center, clock: clock)
        self.notifier = notifier
        running = Task { await notifier.run() }
    }

    /// The bodies of the latest replacement.
    var pendingBodies: [String]? { center.replacements.last?.map(\.body) }

    func cleanUp() {
        running.cancel()
        fresh.cleanUp()
    }
}

/// Polls until `condition` holds; false if it never did.
@MainActor
private func eventually(_ condition: () -> Bool) async throws -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try await Task.sleep(for: .milliseconds(10))
    }
    return false
}

private let cityPharmacy = "Moved the City Pharmacy receipt to Trash. It’s there for 30 days if you need it."

@MainActor
@Test func plansAtStart() async throws {
    let harness = try NotifierHarness([expiring("City Pharmacy", daysAhead: 3)])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.pendingBodies == [cityPharmacy] })
}

@MainActor
@Test func libraryChangeReschedules() async throws {
    let scan = expiring("City Pharmacy", daysAhead: 3)
    let harness = try NotifierHarness([scan])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.pendingBodies == [cityPharmacy] })

    try harness.library.rename(scan.id, to: "Corner Market")

    #expect(
        try await eventually {
            harness.pendingBodies == [
                "Moved the Corner Market receipt to Trash. It’s there for 30 days if you need it."
            ]
        })
}

@MainActor
@Test func turningNotesOffClearsPending() async throws {
    let harness = try NotifierHarness([expiring("City Pharmacy", daysAhead: 3)])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.pendingBodies == [cityPharmacy] })

    harness.preferences.notificationsOn = false

    #expect(try await eventually { harness.pendingBodies == [] })
}

@MainActor
@Test func newDayReschedules() async throws {
    // Enters Trash tomorrow, so once tomorrow is today there is nothing left to announce.
    let harness = try NotifierHarness([expiring("City Pharmacy", daysAhead: 1)])
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.pendingBodies == [cityPharmacy] })

    harness.now.set(noon.addingTimeInterval(86_400))
    harness.today.refresh()

    #expect(try await eventually { harness.pendingBodies == [] })
}

@MainActor
@Test func blockedNotesPlanNothing() async throws {
    let harness = try NotifierHarness([expiring("City Pharmacy", daysAhead: 3)], authorization: .denied)
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.pendingBodies == [] })
}

@MainActor
@Test func rescheduleReadsTheClockAndAuthorizationAgain() async throws {
    // Neither iOS allowing notes in Settings nor a time-zone change moves anything the notifier observes.
    let harness = try NotifierHarness([expiring("City Pharmacy", daysAhead: 3)], authorization: .notDetermined)
    defer { harness.cleanUp() }
    #expect(try await eventually { harness.pendingBodies == [] })
    _ = await harness.center.requestAuthorization()

    harness.notifier.reschedule()

    #expect(try await eventually { harness.pendingBodies == [cityPharmacy] })
}
