import Core
import XCTest

/// The first-launch welcome (`-ShowWelcome`; every other journey starts past it, M1): Continue, then "Know when it
/// cleans up" or straight to Home when iOS already has an answer, and a sheet that can't be swiped away.
@MainActor
final class WelcomeJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAlreadyAllowedSkipsTheAsk() {
        let app = launchApp(["-ShowWelcome", "-Notifications", "authorized"])
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))

        continueButton.tap()

        XCTAssertTrue(continueButton.disappears(within: 5))
        XCTAssertFalse(app.buttons[AccessibilityID.Welcome.turnOn].exists)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isHittable == true", within: 5))
    }

    func testContinueThenNotNowLandsOnEmptyHome() throws {
        let app = launchApp(["-ShowWelcome", "-Notifications", "notDetermined"])
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))
        XCTAssertEqual(continueButton.label, "Continue")
        XCTAssertTrue(app.staticTexts["Welcome to\nFiling Cabinet"].exists)
        attach(app, named: "welcome")
        try audit(app)

        continueButton.tap()

        let notNow = app.buttons[AccessibilityID.Welcome.notNow]
        XCTAssertTrue(notNow.appears(within: 5))
        XCTAssertEqual(app.buttons[AccessibilityID.Welcome.turnOn].label, "Turn on notifications")
        XCTAssertEqual(notNow.label, "Not now")
        attach(app, named: "notifications-ask")
        try audit(app)

        notNow.tap()

        XCTAssertTrue(notNow.disappears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isHittable == true", within: 5))
        attach(app, named: "empty-home")
    }

    func testStuckNotificationServiceStillLetsContinueAndNotNow() {
        // iOS never says whether it allows notes: Continue shows the ask after its wait, and Not now closes it.
        let app = launchApp(["-ShowWelcome", "-NotificationsUnanswered"])
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))

        continueButton.tap()

        let notNow = app.buttons[AccessibilityID.Welcome.notNow]
        XCTAssertTrue(notNow.appears(within: 5))
        notNow.tap()
        XCTAssertTrue(notNow.disappears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isHittable == true", within: 5))
    }

    func testTurnOnAsksIOS() {
        // The fake notification center stands in for iOS's ask (01-05) and allows.
        let app = launchApp(["-ShowWelcome", "-Notifications", "notDetermined"])
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))
        continueButton.tap()
        let turnOn = app.buttons[AccessibilityID.Welcome.turnOn]
        XCTAssertTrue(turnOn.appears(within: 5))

        turnOn.tap()

        XCTAssertTrue(turnOn.disappears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isHittable == true", within: 5))
    }

    func testWelcomeCannotBeSwipedAway() {
        let app = launchApp(["-ShowWelcome", "-Notifications", "notDetermined"])
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))
        let window = app.windows.firstMatch

        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)))

        XCTAssertTrue(continueButton.satisfies("isHittable == true", within: 5))
        XCTAssertFalse(app.buttons[AccessibilityID.Home.scan].isHittable)
    }

    func testAuditAtLargestTextOfBothScreens() throws {
        let app = launchApp(["-ShowWelcome", "-Notifications", "notDetermined"], largestText: true)
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))
        XCTAssertTrue(continueButton.isHittable)
        attach(app, named: "welcome-ax")
        try audit(app)

        continueButton.tap()

        let notNow = app.buttons[AccessibilityID.Welcome.notNow]
        XCTAssertTrue(notNow.appears(within: 5))
        XCTAssertTrue(notNow.isHittable)
        XCTAssertTrue(app.buttons[AccessibilityID.Welcome.turnOn].isHittable)
        attach(app, named: "notifications-ask-ax")
        try audit(app)
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
