import Core
import Foundation
import Testing

@testable import ScreenModels
@testable import TestSupport

/// A welcome on its own defaults, with a scripted notification center.
@MainActor
private struct WelcomeHarness {
    let preferences: AppPreferences
    let center: FakeNotificationCenter
    let analytics = RecordingAnalytics()
    let model: WelcomeModel
    private let fresh: FreshDefaults

    init(_ authorization: NotificationAuthorization, grantsRequest: Bool = true, answers: Bool = true) throws {
        fresh = try FreshDefaults()
        preferences = AppPreferences(defaults: fresh.defaults)
        center = FakeNotificationCenter(authorization: authorization, grantsRequest: grantsRequest, answers: answers)
        model = WelcomeModel(preferences: preferences, notifications: center, analytics: analytics)
    }

    /// Another model on the same defaults, as after the app was killed and opened again.
    func relaunched() -> WelcomeModel {
        WelcomeModel(
            preferences: AppPreferences(defaults: fresh.defaults), notifications: center, analytics: analytics)
    }

    func cleanUp() { fresh.cleanUp() }
}

@Test func freshInstallStartsOnWelcome() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    #expect(!harness.model.isFinished)
    await harness.model.start()
    #expect(harness.model.step == .welcome)
    #expect(!harness.model.isFinished)
}

@Test func doneNeverShows() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    harness.preferences.welcomeDone = true
    await harness.model.start()
    #expect(harness.model.step == nil)
    #expect(harness.model.isFinished)
    #expect(harness.analytics.events.isEmpty)
}

@Test func continueGoesToNotifications() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.continueTapped()
    #expect(harness.model.step == .notifications)
    #expect(!harness.model.isFinished)
    #expect(harness.center.requestCount == 0)
}

@Test(arguments: [NotificationAuthorization.authorized, .denied])
func answeredSkipsSecondScreen(_ authorization: NotificationAuthorization) async throws {
    let harness = try WelcomeHarness(authorization)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.continueTapped()
    #expect(harness.model.step == nil)
    #expect(harness.model.isFinished)
    #expect(harness.preferences.welcomeDone)
    #expect(harness.center.requestCount == 0)
}

@Test func turnOnAsksThenFinishes() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.continueTapped()
    await harness.model.turnOnTapped()
    #expect(harness.center.requestCount == 1)
    #expect(harness.model.step == nil)
    #expect(harness.model.isFinished)
    #expect(harness.preferences.welcomeDone)
}

@Test func notNowFinishesWithoutAsking() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.continueTapped()
    harness.model.notNowTapped()
    #expect(harness.center.requestCount == 0)
    #expect(harness.model.step == nil)
    #expect(harness.preferences.welcomeDone)
}

@Test func unansweredAskClosesOnReturn() async throws {
    let harness = try WelcomeHarness(.notDetermined, answers: false)
    defer { harness.cleanUp() }
    await harness.model.start()
    // Continue would wait on the stuck service too, so the second screen is reached as Continue would have.
    let ask = Task { await harness.model.turnOnTapped() }
    defer { ask.cancel() }
    while harness.center.requestCount == 0 { await Task.yield() }
    #expect(harness.model.step != nil)

    harness.model.becameActive()

    #expect(harness.model.step == nil)
    #expect(harness.preferences.welcomeDone)
    #expect(harness.analytics.events == [.welcomeFinished(notifications: false)])
}

@Test func becomingActiveWithoutAnAskChangesNothing() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    await harness.model.start()
    harness.model.becameActive()
    #expect(harness.model.step == .welcome)
    await harness.model.continueTapped()
    harness.model.becameActive()
    #expect(harness.model.step == .notifications)
}

@Test func killedOnSecondScreenStartsOver() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.continueTapped()
    #expect(harness.model.step == .notifications)

    let again = harness.relaunched()
    await again.start()
    #expect(again.step == .welcome)
}

@Test func analyticsSayWhetherNotificationsWereAllowed() async throws {
    let allowed = try WelcomeHarness(.notDetermined, grantsRequest: true)
    defer { allowed.cleanUp() }
    await allowed.model.start()
    await allowed.model.continueTapped()
    await allowed.model.turnOnTapped()
    #expect(allowed.analytics.events == [.welcomeFinished(notifications: true)])

    let refused = try WelcomeHarness(.notDetermined, grantsRequest: false)
    defer { refused.cleanUp() }
    await refused.model.start()
    await refused.model.continueTapped()
    await refused.model.turnOnTapped()
    #expect(refused.analytics.events == [.welcomeFinished(notifications: false)])

    let later = try WelcomeHarness(.notDetermined)
    defer { later.cleanUp() }
    await later.model.start()
    await later.model.continueTapped()
    later.model.notNowTapped()
    #expect(later.analytics.events == [.welcomeFinished(notifications: false)])

    let already = try WelcomeHarness(.authorized)
    defer { already.cleanUp() }
    await already.model.start()
    await already.model.continueTapped()
    #expect(already.analytics.events == [.welcomeFinished(notifications: true)])
}

@Test func finishesOnlyOnce() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.continueTapped()
    harness.model.notNowTapped()
    harness.model.notNowTapped()
    await harness.model.turnOnTapped()
    #expect(harness.analytics.events.count == 1)
    #expect(harness.center.requestCount == 0)
}
