import Core
import XCTest

extension XCTestCase {
    /// The app, started with `-UITest` (in-memory library, no animations) plus `flags`; `largestText` at the
    /// largest accessibility text size.
    ///
    /// The first test of each class launches the app. Later tests of the class start in the running app through
    /// `RelaunchURL`: it builds a new environment from the flags and every view again, so a test sees a fresh app
    /// for about 1 s instead of a 10 s launch on CI. A real launch still happens when the text size changes
    /// (it is fixed at launch) or when `fresh` asks for one (a cold launch is what the test checks). XCTest runs a
    /// class's tests in name order, so largest-text tests are named `testAuditAtLargestText…` to run together and
    /// share one launch.
    @MainActor
    func launchApp(_ flags: [String] = [], largestText: Bool = false, fresh: Bool = false) -> XCUIApplication {
        let arguments = ["-UITest"] + flags
        let launch = RunningApp.Launch(testClass: ObjectIdentifier(type(of: self)), largestText: largestText)
        if !fresh, let app = RunningApp.app, RunningApp.launch == launch, app.state == .runningForeground,
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
        RunningApp.launch = launch
        return app
    }
}

/// The app the last test launched, and what can only change with a new launch.
@MainActor
private enum RunningApp {
    struct Launch: Equatable {
        let testClass: ObjectIdentifier
        let largestText: Bool
    }

    static var app: XCUIApplication?
    static var launch: Launch?
}
