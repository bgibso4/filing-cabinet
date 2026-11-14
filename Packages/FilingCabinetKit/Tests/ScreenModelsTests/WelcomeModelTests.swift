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
        let wait = answers ? Self.answeredWait : Self.stuckWait
        model = WelcomeModel(
            preferences: preferences, notifications: center, analytics: analytics, authorizationWait: wait)
    }

    /// When the fake answers, a bound it can never lose to on a busy machine; the read returns as soon as it answers.
    static let answeredWait = Duration.seconds(10)
    /// When the fake never answers, the bound is what the test waits out, so it stays short.
    static let stuckWait = Duration.milliseconds(50)

    /// Starts Turn on notifications from the second screen and returns once iOS has been asked.
    func askAndWait() async -> Task<Void, Never> {
        await model.start()
        await model.continueTapped()
        let ask = Task { await model.turnOnTapped() }
        while center.requestCount == 0 { await Task.yield() }
        return ask
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

@Test func stuckServiceStillReachesTheAsk() async throws {
    let harness = try WelcomeHarness(.notDetermined, answers: false)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.continueTapped()
    #expect(harness.model.step == .notifications)
    harness.model.notNowTapped()
    #expect(harness.model.step == nil)
    #expect(harness.analytics.events == [.welcomeFinished(notifications: false)])
}

@Test func unansweredAskClosesOnReturn() async throws {
    let harness = try WelcomeHarness(.notDetermined, answers: false)
    defer { harness.cleanUp() }
    let ask = await harness.askAndWait()
    defer { ask.cancel() }
    #expect(harness.model.step == .notifications)

    harness.model.becameActive()

    #expect(harness.model.step == nil)
    #expect(harness.preferences.welcomeDone)
    // The answer never came, so there is nothing true to report.
    #expect(harness.analytics.events.isEmpty)
}

@Test func answerAfterReturnIsReported() async throws {
    let harness = try WelcomeHarness(.notDetermined, grantsRequest: true, answers: false)
    defer { harness.cleanUp() }
    let ask = await harness.askAndWait()
    harness.model.becameActive()
    #expect(harness.model.step == nil)
    #expect(harness.analytics.events.isEmpty)

    // The stuck fake answers once cancelled: iOS's answer arriving after the app became active.
    ask.cancel()
    await ask.value

    #expect(harness.analytics.events == [.welcomeFinished(notifications: true)])
    harness.model.becameActive()
    #expect(harness.analytics.events.count == 1)
}

@Test func turnOnWorksOnlyOnTheAsk() async throws {
    let harness = try WelcomeHarness(.notDetermined)
    defer { harness.cleanUp() }
    await harness.model.start()
    await harness.model.turnOnTapped()
    #expect(harness.center.requestCount == 0)
    #expect(harness.model.step == .welcome)
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
    harness.model.becameActive()
    #expect(harness.analytics.events.count == 1)
    #expect(harness.center.requestCount == 0)
}
