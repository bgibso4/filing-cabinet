/// Extra time iOS gives a job still running when the app leaves the foreground. The app's is UIKit's background task;
/// tests fake it. ScreenModels doesn't import UIKit, so this is the seam.
public protocol BackgroundTime {
    /// Asks for time to finish the job called `name`; call the returned closure once it is done. If iOS's time runs
    /// out first, `expired` runs and the time has ended (calling the closure later does nothing).
    func begin(_ name: String, expired: @escaping @MainActor @Sendable () -> Void) -> () -> Void
}
