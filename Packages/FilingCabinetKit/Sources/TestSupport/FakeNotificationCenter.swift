import Core
import Synchronization

/// Test double for `CleanupNotifying`: answers with a scripted authorization and records every replacement.
public final class FakeNotificationCenter: CleanupNotifying {
    private struct State {
        var authorization: NotificationAuthorization
        var requestCount = 0
        var replacements: [[ScheduledNotice]] = []
    }

    /// How long `authorization()` takes to answer when it doesn't answer: longer than any test.
    private static let unansweredWait = Duration.seconds(3600)

    private let state: Mutex<State>
    private let grantsRequest: Bool
    private let answers: Bool

    /// `grantsRequest` is what the person answers when asked while `.notDetermined`. Unless it `answers`,
    /// `authorization()` and `requestAuthorization()` wait until cancelled, like a stuck notification service; a
    /// request is counted before it waits.
    public init(authorization: NotificationAuthorization, grantsRequest: Bool = true, answers: Bool = true) {
        state = Mutex(State(authorization: authorization))
        self.grantsRequest = grantsRequest
        self.answers = answers
    }

    package var requestCount: Int { state.withLock { $0.requestCount } }

    /// Every `replacePending` argument, in call order.
    package var replacements: [[ScheduledNotice]] { state.withLock { $0.replacements } }

    public func authorization() async -> NotificationAuthorization {
        await waitIfUnanswered()
        return state.withLock { $0.authorization }
    }

    public func requestAuthorization() async -> Bool {
        state.withLock { $0.requestCount += 1 }
        await waitIfUnanswered()
        let granted = grantsRequest
        return state.withLock {
            // iOS asks only once: later requests just report what the person chose.
            if $0.authorization == .notDetermined { $0.authorization = granted ? .authorized : .denied }
            return $0.authorization == .authorized
        }
    }

    private func waitIfUnanswered() async {
        guard !answers else { return }
        // try?: cancellation is the only way out of the wait, and it answers then.
        try? await Task.sleep(for: Self.unansweredWait)
    }

    public func replacePending(with notices: [ScheduledNotice]) async {
        state.withLock { $0.replacements.append(notices) }
    }
}
