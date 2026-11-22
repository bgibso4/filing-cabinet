import Core
import XCTest

/// The first-launch welcome and its notifications ask, at the default and the largest text size.
@MainActor
final class WelcomeAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextOfBothScreens() throws {
        try auditBothScreens(largestText: true)
    }

    func testAuditBothScreens() throws {
        try auditBothScreens(largestText: false)
    }

    private func auditBothScreens(largestText: Bool) throws {
        let suffix = largestText ? "-ax" : ""
        let app = launchApp(["-ShowWelcome", "-Notifications", "notDetermined"], largestText: largestText)
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))
        XCTAssertTrue(continueButton.isHittable)
        attachScreenshot(of: app, named: "welcome\(suffix)")
        try audit(app)

        continueButton.tap()

        let notNow = app.buttons[AccessibilityID.Welcome.notNow]
        XCTAssertTrue(notNow.appears(within: 5))
        XCTAssertTrue(notNow.isHittable)
        XCTAssertTrue(app.buttons[AccessibilityID.Welcome.turnOn].isHittable)
        attachScreenshot(of: app, named: "notifications-ask\(suffix)")
        try audit(app)
    }
}
