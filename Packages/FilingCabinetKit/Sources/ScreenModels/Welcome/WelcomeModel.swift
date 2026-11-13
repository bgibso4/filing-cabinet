import Core
import Observation

/// The first-launch welcome (01-03), then "Know when it cleans up" (01-04) and iOS's notification ask (01-05). It shows
/// at every launch until it is completed, and nothing else asks for anything while it is up (Plan 6 §4).
@MainActor
@Observable
public final class WelcomeModel {
    public enum Step: Equatable, Sendable {
        case welcome
        case notifications
    }

    /// The screen showing; nil when the welcome is finished, never needed or not started.
    public private(set) var step: Step?

    /// True while "Turn on notifications" waits for iOS's answer.
    @ObservationIgnored private var isAsking = false

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let notifications: any CleanupNotifying
    @ObservationIgnored private let analytics: any Analytics

    public init(preferences: AppPreferences, notifications: any CleanupNotifying, analytics: any Analytics) {
        self.preferences = preferences
        self.notifications = notifications
        self.analytics = analytics
    }

    /// Completed on this install, so the rating prompt and requests from outside the app no longer wait for it.
    public var isFinished: Bool { preferences.welcomeDone }

    /// Shows the welcome unless it was completed. Starting again keeps the screen already showing.
    public func start() async {
        guard !preferences.welcomeDone, step == nil else { return }
        step = .welcome
    }

    /// Continue: the notifications screen, unless iOS already has an answer (M2).
    public func continueTapped() async {
        guard step == .welcome else { return }
        switch await notifications.authorization() {
        case .notDetermined: step = .notifications
        case .authorized: finish(notifications: true)
        case .denied: finish(notifications: false)
        }
    }

    /// Turn on notifications: iOS asks, and the welcome closes whatever the answer (M11).
    public func turnOnTapped() async {
        guard step != nil, !isAsking else { return }
        isAsking = true
        let allowed = await notifications.requestAuthorization()
        isAsking = false
        finish(notifications: allowed)
    }

    /// Not now: closes without asking.
    public func notNowTapped() {
        finish(notifications: false)
    }

    /// The app is active again. After iOS's ask, that means the person answered; if the answer hasn't come back (a
    /// stuck notification service), the welcome closes anyway, so it never traps them (M11).
    public func becameActive() {
        guard isAsking else { return }
        finish(notifications: false)
    }

    private func finish(notifications allowed: Bool) {
        guard step != nil else { return }
        step = nil
        preferences.welcomeDone = true
        analytics.send(.welcomeFinished(notifications: allowed))
    }
}
