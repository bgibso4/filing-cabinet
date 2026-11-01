import Core
import ScreenModels
import UIKit

/// The app's collaborators, built once at launch.
@MainActor
final class AppEnvironment {
    // periphery:ignore - held for the screens that log events; only the lifecycle model uses it so far.
    let analytics: any Analytics
    let home: HomeModel
    let lifecycle: AppLifecycleModel

    init(analytics: any Analytics) {
        self.analytics = analytics
        home = HomeModel()
        lifecycle = AppLifecycleModel(analytics: analytics)
    }

    /// Launch flags (UI tests and `make run-fake`): `-UITest` logs analytics and turns animations off.
    /// Unknown flags are ignored. Real and UI-test runs both log analytics until TelemetryDeck is connected.
    static func make(arguments: [String]) -> AppEnvironment {
        if arguments.contains("-UITest") {
            UIView.setAnimationsEnabled(false)
        }
        return AppEnvironment(analytics: LogAnalytics())
    }
}
