import XCTest

/// Launches the app with the `-UITest` flag (disables animations; no fake services yet) plus any extra flags.
/// `largestText` launches at the largest accessibility text size.
@MainActor
func launchApp(_ flags: [String] = [], largestText: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    let text = largestText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
    app.launchArguments = ["-UITest"] + flags + text
    app.launch()
    return app
}
