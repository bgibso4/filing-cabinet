import ScreenModels
import UIKit

/// UIKit's background task: a little extra time for a job still running when the app leaves the foreground.
@MainActor
final class SystemBackgroundTime: BackgroundTime {
    func begin(_ name: String, expired: @escaping @MainActor @Sendable () -> Void) -> () -> Void {
        let task = BackgroundTask()
        task.id = UIApplication.shared.beginBackgroundTask(withName: name) {
            expired()
            // iOS ends the app if the time isn't ended before this handler returns.
            task.end()
        }
        return { task.end() }
    }
}

/// One request for background time, ended once whichever of the job or iOS's time ends first.
@MainActor
private final class BackgroundTask {
    var id = UIBackgroundTaskIdentifier.invalid

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
