import Core
import XCTest

/// Settings, Collections and one collection's settings, with notifications blocked in iPhone Settings, and the lock's
/// row in its three states, at the default and the largest text size.
@MainActor
final class SettingsAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextOfTheLockRow() throws {
        let app = launchApp(["-SeedScans", "3", "-Authenticator", "succeeds", "-Lock", "on"], largestText: true)
        let lock = openLockSwitch(in: app)
        XCTAssertEqual(lock.value as? String, "1")
        try audit(app)
    }

    func testAuditAtLargestTextSettings() throws {
        let app = seededLibrary(largestText: true, flags: ["-Notifications", "denied"])
        try auditSettingsCollectionsAndThrowaways(in: app)
    }

    func testAuditSettings() throws {
        let app = seededLibrary(flags: ["-Notifications", "denied"])
        try auditSettingsCollectionsAndThrowaways(in: app)
    }

    /// On, the footer adds the backup advice.
    func testAuditTheLockRowOn() throws {
        let app = launchApp(["-SeedScans", "3", "-Authenticator", "succeeds", "-Lock", "on"])
        let lock = openLockSwitch(in: app)
        XCTAssertEqual(lock.value as? String, "1")
        let advice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Advanced Data Protection'"))
        XCTAssertTrue(advice.firstMatch.appears(within: 5))
        try audit(app)
    }

    /// With no passcode on the phone the switch is disabled and says why.
    func testAuditTheLockRowWithoutAPasscode() throws {
        let app = launchApp(["-SeedScans", "3", "-Authenticator", "none"])
        let lock = openLockSwitch(in: app)
        XCTAssertFalse(lock.isEnabled)
        try audit(app)
    }

    // MARK: Steps

    private func auditSettingsCollectionsAndThrowaways(in app: XCUIApplication) throws {
        app.openSettings()
        try audit(app)
        app.buttons[AccessibilityID.Settings.collections].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Collections.row(.throwaways)].appears(within: 5))
        try audit(app)
        app.buttons[AccessibilityID.Collections.row(.throwaways)].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.CollectionSettings.keepScansFor].appears(within: 5))
        try audit(app)
    }

    /// Settings' lock switch, scrolled to where it can be tapped (at the largest text it starts below the fold).
    private func openLockSwitch(in app: XCUIApplication) -> XCUIElement {
        app.openSettings()
        let lock = app.switches[AccessibilityID.Settings.lockSwitch]
        if !lock.isHittable {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTAssertTrue(lock.satisfies("isHittable == true", within: 5))
        return lock
    }
}
