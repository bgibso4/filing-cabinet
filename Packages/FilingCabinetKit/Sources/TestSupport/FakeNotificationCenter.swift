import Core
import Synchronization

/// Test double for `CleanupNotifying`: answers with a scripted authorization and records every replacement.
package final class FakeNotificationCenter: CleanupNotifying {
    private struct State {
        var authorization: NotificationAuthorization
        var requestCount = 0
        var replacements: [[ScheduledNotice]] = []
    }

    private let state: Mutex<State>
    private let grantsRequest: Bool

    /// `grantsRequest` is what the person answers when asked while `.notDetermined`.
    package init(authorization: NotificationAuthorization, grantsRequest: Bool = true) {
        state = Mutex(State(authorization: authorization))
        self.grantsRequest = grantsRequest
    }

    package var requestCount: Int { state.withLock { $0.requestCount } }

    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    /// Every `replacePending` argument, in call order.
    package var replacements: [[ScheduledNotice]] { state.withLock { $0.replacements } }

    package func authorization() async -> NotificationAuthorization { state.withLock { $0.authorization } }

    package func requestAuthorization() async -> Bool {
        let granted = grantsRequest
        return state.withLock {
            $0.requestCount += 1
            // iOS asks only once: later requests just report what the person chose.
            if $0.authorization == .notDetermined { $0.authorization = granted ? .authorized : .denied }
            return $0.authorization == .authorized
        }
    }

    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    package func replacePending(with notices: [ScheduledNotice]) async {
        state.withLock { $0.replacements.append(notices) }
    }
}
