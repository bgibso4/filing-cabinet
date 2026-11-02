import Core
import Observation

/// Turns app lifecycle moments into analytics events.
@Observable
public final class AppLifecycleModel {
    private let analytics: any Analytics

    public init(analytics: any Analytics) {
        self.analytics = analytics
    }

    public func sceneBecameActive() {
        analytics.send(.appOpened)
    }
}
