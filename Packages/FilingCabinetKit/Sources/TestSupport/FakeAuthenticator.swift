import Core
import Synchronization

/// Test double for `DeviceAuthenticating`: answers with scripted results and records every reason it was given.
public final class FakeAuthenticator: DeviceAuthenticating {
    private struct State {
        var availability: AuthenticationAvailability
        var nextResult = 0
        var reasons: [String] = []
    }

    private let state: Mutex<State>
    private let results: [AuthenticationResult]

    /// `results` are returned in order and the last repeats; with none, every check succeeds.
    public init(availability: AuthenticationAvailability, results: [AuthenticationResult] = [.success]) {
        state = Mutex(State(availability: availability))
        self.results = results.isEmpty ? [.success] : results
    }

    /// What `availability()` reports (a property can't share its name); a test changes it to model Face ID being switched off.
    public var currentAvailability: AuthenticationAvailability {
        get { state.withLock { $0.availability } }
        set { state.withLock { $0.availability = newValue } }
    }

    /// The `reason` of every `authenticate` call, in call order.
    public var reasons: [String] { state.withLock { $0.reasons } }

    public func availability() -> AuthenticationAvailability { currentAvailability }

    public func authenticate(reason: String) async -> AuthenticationResult {
        state.withLock {
            $0.reasons.append(reason)
            let result = results[min($0.nextResult, results.count - 1)]
            $0.nextResult += 1
            return result
        }
    }
}
