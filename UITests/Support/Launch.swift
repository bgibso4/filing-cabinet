import Core
import XCTest

extension XCTestCase {
    /// The app, started with `-UITest` (in-memory library, no animations) plus `flags`; `largestText` at the
    /// largest accessibility text size.
    ///
    /// The first test of each class launches the app. Later tests of the class start in the running app through
    /// `RelaunchURL`: it builds a new environment from the flags and every view again, so a test sees a fresh app
    /// for about 1 s instead of a 10 s launch on CI. A real launch still happens when the text size changes
    /// (it is fixed at launch), after a test that failed (the app may be stuck, and a stuck process survives a
    /// relaunch), or when `fresh` asks for one (a cold launch is what the test checks). XCTest runs a
    /// class's tests in name order, so largest-text tests are named `testAuditAtLargestText…` to run together and
    /// share one launch.
    @MainActor
    func launchApp(_ flags: [String] = [], largestText: Bool = false, fresh: Bool = false) -> XCUIApplication {
        let arguments = ["-UITest"] + flags
        let testClass = ObjectIdentifier(type(of: self))
        // After a failure the app may be stuck (a hang survives a relaunch), so the next test starts a new process.
        if !fresh, !RunningApp.failures.seenSinceLaunch, let app = RunningApp.app, RunningApp.testClass == testClass,
            RunningApp.largestText == largestText, app.state == .runningForeground,
            let url = RelaunchURL.make(arguments: arguments)
        {
            // The system opens it in the running app. `app.open(url)` would set up a new automation session, which
            // costs as much as a launch.
            XCUIDevice.shared.system.open(url)
            return app
        }
        let app = XCUIApplication()
        let text =
            largestText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
        app.launchArguments = arguments + text
        app.launch()
        RunningApp.app = app
        RunningApp.testClass = testClass
        RunningApp.largestText = largestText
        RunningApp.failures.seenSinceLaunch = false
        return app
    }
}

/// The app the last test launched, and what can only change with a new launch: the test class that launched it
/// and its text size.
@MainActor
private enum RunningApp {
    static var app: XCUIApplication?
    static var testClass: ObjectIdentifier?
    static var largestText = false
    static let failures = FailureWatch()
}

/// Notes any failure XCTest records, so the next test launches the app again.
@MainActor
private final class FailureWatch: NSObject, XCTestObservation {
    var seenSinceLaunch = false

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    nonisolated func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        // UI tests record their issues on the main thread; anything else still lands before the next test asks.
        if Thread.isMainThread {
            MainActor.assumeIsolated { seenSinceLaunch = true }
        } else {
            Task { @MainActor in seenSinceLaunch = true }
        }
    }
}
