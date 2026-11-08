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

private func scan(_ collection: BuiltInCollection, daysOld: Int) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: "Synthetic",
        collection: collection,
        scannedAt: noon.addingTimeInterval(-Double(daysOld) * 86_400),
        expiryOverride: nil,
        pageCount: 1)
}

/// Fresh defaults per test, so no test sees another's preferences.
@MainActor
private func freshPreferences() throws -> AppPreferences {
    let suite = "SettingsModelTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    return AppPreferences(defaults: defaults)
}

@MainActor
private struct SettingsHarness {
    let preferences: AppPreferences
    let center: FakeNotificationCenter
    let model: SettingsModel

    init(_ authorization: NotificationAuthorization, grantsRequest: Bool = true) throws {
        preferences = try freshPreferences()
        center = FakeNotificationCenter(authorization: authorization, grantsRequest: grantsRequest)
        model = SettingsModel(preferences: preferences, notifications: center, version: "1.0")
    }
}

@MainActor
@Test func collectionsCountIsFive() throws {
    #expect(try SettingsHarness(.authorized).model.collectionsCount == 5)
}

@MainActor
@Test func footerNamesTheVersion() throws {
    #expect(try SettingsHarness(.authorized).model.footer == "Filing Cabinet 1.0 · Private by design")
}

@MainActor
@Test func switchIsOffUntilAuthorized() async throws {
    let harness = try SettingsHarness(.authorized)
    #expect(harness.preferences.notificationsOn)
    #expect(!harness.model.notificationsSwitchIsOn)
    await harness.model.refreshAuthorization()
    #expect(harness.model.notificationsSwitchIsOn)
    #expect(harness.model.notificationsNote == "A note when scans move to Trash")
}

@MainActor
@Test func turningOnAsksWhenNotDetermined() async throws {
    let harness = try SettingsHarness(.notDetermined)
    await harness.model.refreshAuthorization()
    #expect(!harness.model.notificationsSwitchIsOn)
    let action = await harness.model.setNotifications(true)
    #expect(action == nil)
    #expect(harness.center.requestCount == 1)
    #expect(harness.model.notificationsSwitchIsOn)
}

@MainActor
@Test func refusingTheAskLeavesTheSwitchOffWithTheSettingsNote() async throws {
    let harness = try SettingsHarness(.notDetermined, grantsRequest: false)
    await harness.model.refreshAuthorization()
    _ = await harness.model.setNotifications(true)
    #expect(!harness.model.notificationsSwitchIsOn)
    #expect(harness.model.notificationsNote == "Turned off in iPhone Settings")
}

@MainActor
@Test func deniedOpensSystemSettings() async throws {
    let harness = try SettingsHarness(.denied)
    await harness.model.refreshAuthorization()
    #expect(harness.model.notificationsNote == "Turned off in iPhone Settings")
    let action = await harness.model.setNotifications(true)
    #expect(action == .openSystemSettings)
    #expect(harness.center.requestCount == 0)
    #expect(!harness.model.notificationsSwitchIsOn)
}

@MainActor
@Test func turningOffStopsNotes() async throws {
    let harness = try SettingsHarness(.authorized)
    await harness.model.refreshAuthorization()
    let action = await harness.model.setNotifications(false)
    #expect(action == nil)
    #expect(!harness.preferences.notificationsOn)
    #expect(!harness.model.notificationsSwitchIsOn)
}

@MainActor
@Test func preferencesSurviveANewInstance() throws {
    let suite = "SettingsModelTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let first = AppPreferences(defaults: defaults)
    first.notificationsOn = false
    first.cleanupSeenThrough = oct12
    let second = AppPreferences(defaults: defaults)
    #expect(!second.notificationsOn)
    #expect(second.cleanupSeenThrough == oct12)
    #expect(AppPreferences(defaults: UserDefaults(suiteName: "\(suite)-empty") ?? defaults).cleanupSeenThrough == nil)
}

// MARK: - Collections

@MainActor
@Test func collectionRowsReadKeptAndCount() {
    let clock = AppClock.fixed(noon, calendar: utc)
    let library = FakeLibrary(
        scans: [scan(.wallet, daysOld: 5), scan(.wallet, daysOld: 400), scan(.receipts, daysOld: 10)], clock: clock)
    let model = CollectionsModel(library: library, today: Today(clock: clock), calendar: utc)
    #expect(model.rows.map(\.collection) == BuiltInCollection.allCases)
    #expect(model.rows.map(\.name).first == "Wallet")
    #expect(model.rows.map(\.detail).first == "Kept forever · 2 scans")
    #expect(model.rows.first { $0.collection == .receipts }?.detail == "Kept 3 months · 1 scan")
    #expect(model.rows.first { $0.collection == .notes }?.detail == "Kept forever · No scans")
    #expect(model.subtitle == "How long each one keeps scans")
    #expect(model.footer == "Counted from each scan’s date.")
}
