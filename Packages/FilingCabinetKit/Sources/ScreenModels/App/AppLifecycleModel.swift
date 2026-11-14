import Core
import Observation

/// Turns app lifecycle moments into analytics events: one `appOpened` per stay in the foreground, whether launch or the
/// scene becoming active tells it first.
@Observable
public final class AppLifecycleModel {
    private let analytics: any Analytics
    /// True from the stay's `appOpened` until the app goes to the background.
    @ObservationIgnored private var isCounted = false

    public init(analytics: any Analytics) {
        self.analytics = analytics
    }

    /// The environment is made at launch.
    public func launched() {
        countOpen()
    }

    public func sceneBecameActive() {
        countOpen()
    }

    /// The app went to the background: the next return counts again.
    public func sceneLeftForeground() {
        isCounted = false
    }

    private func countOpen() {
        guard !isCounted else { return }
        isCounted = true
        analytics.send(.appOpened)
    }
}
