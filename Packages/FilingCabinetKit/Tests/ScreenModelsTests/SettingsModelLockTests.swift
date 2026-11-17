import Core
import Foundation
import Testing

@testable import ScreenModels
@testable import TestSupport

@MainActor
private struct LockHarness {
    let preferences: AppPreferences
    let authenticator: FakeAuthenticator
    let model: SettingsModel
    let analytics = RecordingAnalytics()
    private let fresh: FreshDefaults

    init(
        availability: AuthenticationAvailability = .biometrics,
        results: [AuthenticationResult] = [.success],
        lockOn: Bool = false
    ) throws {
        fresh = try FreshDefaults()
        preferences = AppPreferences(defaults: fresh.defaults)
        preferences.lockOn = lockOn
        authenticator = FakeAuthenticator(availability: availability, results: results)
        let suggester = FakeScanSuggester.unavailable()
        let pass = SearchWordsPass(
            library: FakeLibrary(),
            today: Today(clock: .system),
            suggester: suggester,
            preferences: preferences,
            isBusy: { false })
        model = SettingsModel(
            preferences: preferences,
            notifications: FakeNotificationCenter(authorization: .authorized),
            suggester: suggester,
            wordsPass: pass,
            lock: LibraryLock(preferences: preferences, authenticator: authenticator),
            analytics: analytics,
            version: "1.0")
    }

    func cleanUp() { fresh.cleanUp() }
}

private let normalSubtitle = "Asks when you open the app"
private let offFooter = "Scanning from Control Center and the Action button still works while locked."
private let onFooter =
    offFooter
    + " Scans are in your iCloud Backup: turn on Advanced Data Protection to encrypt it end to end, and Stolen Device Protection to guard your phone if it’s stolen."

@MainActor
@Test func offRowIsEnabledWithTheNormalCopy() throws {
    let harness = try LockHarness()
    defer { harness.cleanUp() }
    #expect(
        harness.model.lockRow
            == LockRow(isEnabled: true, isOn: false, subtitle: normalSubtitle, footer: offFooter))
}

@MainActor
@Test func onRowShowsTheBackupAdvice() throws {
    let harness = try LockHarness(lockOn: true)
    defer { harness.cleanUp() }
    #expect(
        harness.model.lockRow == LockRow(isEnabled: true, isOn: true, subtitle: normalSubtitle, footer: onFooter))
}

@MainActor
@Test func noPasscodeAndOffDisablesTheRow() throws {
    let harness = try LockHarness(availability: .none)
    defer { harness.cleanUp() }
    #expect(
        harness.model.lockRow
            == LockRow(
                isEnabled: false,
                isOn: false,
                subtitle: "Set a passcode in iPhone Settings to use this",
                footer: offFooter))
}

@MainActor
@Test func pausedRowStillShowsOnAndStaysEnabled() throws {
    let harness = try LockHarness(availability: .none, lockOn: true)
    defer { harness.cleanUp() }
    #expect(
        harness.model.lockRow
            == LockRow(
                isEnabled: true, isOn: true, subtitle: "Paused · Set a passcode to lock again", footer: onFooter))
}

@MainActor
@Test func rowFollowsThePasscodeOnlyOnceSettingsRefreshes() async throws {
    let harness = try LockHarness(availability: .none)
    defer { harness.cleanUp() }
    #expect(!harness.model.lockRow.isEnabled)
    harness.authenticator.currentAvailability = .biometrics
    #expect(!harness.model.lockRow.isEnabled)
    await harness.model.refreshAuthorization()
    #expect(harness.model.lockRow.isEnabled)
    #expect(harness.model.lockRow.subtitle == normalSubtitle)
}

@MainActor
@Test func turningOnAfterACheckSendsOneEvent() async throws {
    let harness = try LockHarness()
    defer { harness.cleanUp() }
    await harness.model.setLock(true)
    #expect(harness.model.lockRow.isOn)
    #expect(harness.analytics.events == [.lockChanged(isOn: true)])
}

@MainActor
@Test func aCancelledCheckLeavesItOffWithNoEvent() async throws {
    let harness = try LockHarness(results: [.cancelled])
    defer { harness.cleanUp() }
    await harness.model.setLock(true)
    #expect(!harness.model.lockRow.isOn)
    #expect(harness.analytics.events.isEmpty)
}

@MainActor
@Test func aCancelledCheckLeavesItOnWithNoEvent() async throws {
    let harness = try LockHarness(results: [.cancelled], lockOn: true)
    defer { harness.cleanUp() }
    await harness.model.setLock(false)
    #expect(harness.model.lockRow.isOn)
    #expect(harness.analytics.events.isEmpty)
}

@MainActor
@Test func turningOffAfterACheckSendsOneEvent() async throws {
    let harness = try LockHarness(results: [.success], lockOn: true)
    defer { harness.cleanUp() }
    await harness.model.setLock(false)
    #expect(!harness.model.lockRow.isOn)
    #expect(harness.authenticator.reasons.count == 1)
    #expect(harness.analytics.events == [.lockChanged(isOn: false)])
}

@MainActor
@Test func turningOffWhilePausedNeedsNoCheckAndSendsTheEvent() async throws {
    let harness = try LockHarness(availability: .none, results: [.failed], lockOn: true)
    defer { harness.cleanUp() }
    await harness.model.setLock(false)
    #expect(!harness.model.lockRow.isOn)
    #expect(harness.authenticator.reasons.isEmpty)
    #expect(harness.analytics.events == [.lockChanged(isOn: false)])
}
