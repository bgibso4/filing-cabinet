import XCTest

/// Launches the app with the `-UITest` flag (disables animations; no fake services yet) plus any extra flags.
@MainActor
func launchApp(_ flags: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UITest"] + flags
    app.launch()
    return app
}
