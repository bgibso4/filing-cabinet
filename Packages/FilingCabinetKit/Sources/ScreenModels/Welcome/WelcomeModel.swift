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
    /// How long Continue waits for iOS to say whether it allows notes before showing the ask anyway.
    @ObservationIgnored private let authorizationWait: Duration

    /// `authorizationWait` is 1 s in the app; tests shorten it.
    public init(
        preferences: AppPreferences,
        notifications: any CleanupNotifying,
        analytics: any Analytics,
        authorizationWait: Duration = .seconds(1)
    ) {
        self.preferences = preferences
        self.notifications = notifications
        self.analytics = analytics
        self.authorizationWait = authorizationWait
    }

    /// Completed on this install, so the rating prompt and requests from outside the app no longer wait for it.
    public var isFinished: Bool { preferences.welcomeDone }

    /// Shows the welcome unless it was completed. Starting again keeps the screen already showing.
    public func start() async {
        guard !preferences.welcomeDone, step == nil else { return }
        step = .welcome
    }

    /// Continue: the notifications screen, unless iOS already has an answer (M2). When iOS doesn't say within
    /// `authorizationWait`, the notifications screen shows, where Not now always closes the welcome.
    public func continueTapped() async {
        guard step == .welcome else { return }
        switch await authorizationWithinWait() {
        case .notDetermined, nil: step = .notifications
        case .authorized: finish(notifications: true)
        case .denied: finish(notifications: false)
        }
    }

    /// Turn on notifications: iOS asks, and the welcome closes whatever the answer (M11). The answer is reported when
    /// it comes back, even if the welcome already closed on `becameActive()`; if it never comes, nothing is reported.
    public func turnOnTapped() async {
        guard step == .notifications, !isAsking else { return }
        isAsking = true
        let allowed = await notifications.requestAuthorization()
        isAsking = false
        close()
        analytics.send(.welcomeFinished(notifications: allowed))
    }

    /// Not now: closes without asking.
    public func notNowTapped() {
        finish(notifications: false)
    }

    /// The app is active again. After iOS's ask, that means the person answered; if the answer hasn't come back (a
    /// stuck notification service), the welcome closes anyway, so it never traps them (M11). `turnOnTapped()` reports
    /// the answer if it comes.
    public func becameActive() {
        guard isAsking else { return }
        close()
    }

    private func finish(notifications allowed: Bool) {
        guard step != nil else { return }
        close()
        analytics.send(.welcomeFinished(notifications: allowed))
    }

    private func close() {
        step = nil
        preferences.welcomeDone = true
    }

    /// What iOS allows, or nil when it hasn't said within `authorizationWait`. Whichever comes first wins; the other
    /// is cancelled, and a read that ignores cancellation is left to finish on its own.
    private func authorizationWithinWait() async -> NotificationAuthorization? {
        let (answers, continuation) = AsyncStream.makeStream(of: NotificationAuthorization?.self)
        let notifications = notifications
        let wait = authorizationWait
        let reading = Task { continuation.yield(await notifications.authorization()) }
        let timer = Task {
            // try?: a cancelled timer means the answer came first, and then nothing more is read.
            try? await Task.sleep(for: wait)
            continuation.yield(nil)
        }
        var iterator = answers.makeAsyncIterator()
        // The stream only ends after this read, so `next()` always returns one of the two yields.
        let first = await iterator.next().flatMap { $0 }
        continuation.finish()
        reading.cancel()
        timer.cancel()
        return first
    }
}
