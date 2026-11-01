import XCTest

/// Launches the app with the `-UITest` flag (fake services, logged analytics, no animations) plus any extra flags.
@MainActor
func launchApp(_ flags: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UITest"] + flags
    app.launch()
    return app
}
