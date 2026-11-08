import Core
import XCTest

/// Settings from Home's gear: Collections, then Receipts' "Keep scans for". Lengthening asks nothing; shortening so
/// that scans go to Trash now asks first, and Change sends them there. Menus and alerts are never snapshotted, so they
/// are attached as screenshots.
@MainActor
final class SettingsJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Twelve scans dated 0 to 11 days ago, three of them Receipts (1, 6 and 11 days old). iOS has blocked notifications.
    ///
    /// Receipts, not Throwaways: a seeded throwaway older than a week is already in Trash at launch, and a scan in
    /// Trash stays there whatever the lifespan (M1), so no Throwaways change could ask.
    private func seededApp(largestText: Bool = false) -> XCUIApplication {
        launchApp(
            ["-SeedScans", "12", "-FixedDate", "2026-10-12", "-Notifications", "denied"], largestText: largestText)
    }

    func testShorteningAsksThenSendsToTrash() throws {
        let app = seededApp()
        openSettings(in: app)
        let notifications = app.switches[AccessibilityID.Settings.notifications]
        XCTAssertEqual(notifications.value as? String, "0")
        // The switch carries the note: the drawn text beside it is hidden from VoiceOver.
        XCTAssertTrue(notifications.label.hasSuffix("Turned off in iPhone Settings"), notifications.label)
        XCTAssertEqual(app.buttons[AccessibilityID.Settings.collections].label, "Collections, 5")
        try audit(app)

        app.buttons[AccessibilityID.Settings.collections].tap()
        assertIdentifiers(AccessibilityID.Collections.all, in: app)
        XCTAssertEqual(
            app.buttons[AccessibilityID.Collections.row(.receipts)].label, "Receipts, Kept 3 months · 3 scans")
        try audit(app)

        app.buttons[AccessibilityID.Collections.row(.receipts)].tap()
        let keepScansFor = app.buttons[AccessibilityID.CollectionSettings.keepScansFor]
        XCTAssertTrue(keepScansFor.waitForExistence(timeout: 5))
        XCTAssertEqual(keepScansFor.value as? String, "3 months")
        try audit(app)

        // Longer asks nothing.
        keepScansFor.tap()
        XCTAssertTrue(menuItem("1 year", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(menuItem("3 months", in: app).isSelected)
        XCTAssertFalse(menuItem("1 year", in: app).isSelected)
        attachScreenshot("keep-scans-for-menu", of: app)
        menuItem("1 year", in: app).tap()
        XCTAssertTrue(waitFor(keepScansFor, value: "1 year"))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let trashBefore = trashCount(in: app)

        // A week: the 11-day-old receipt would go to Trash now, so it asks first.
        keepScansFor.tap()
        XCTAssertTrue(menuItem("1 week", in: app).waitForExistence(timeout: 5))
        menuItem("1 week", in: app).tap()
        let ask = app.alerts["Keep receipts 1 week?"]
        XCTAssertTrue(ask.waitForExistence(timeout: 5))
        XCTAssertTrue(
            ask.staticTexts[
                "1 receipt is older than a week and will go to Trash now. You can restore them for 30 days."
            ].exists)
        attachScreenshot("shortening-asks-first", of: app)
        ask.buttons["Change"].tap()
        XCTAssertTrue(waitFor(keepScansFor, value: "1 week"))

        XCTAssertEqual(trashCount(in: app), trashBefore + 1)
    }

    func testAuditAtLargestTextSettings() throws {
        let app = seededApp(largestText: true)
        openSettings(in: app)
        try audit(app)
        app.buttons[AccessibilityID.Settings.collections].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Collections.row(.throwaways)].waitForExistence(timeout: 5))
        try audit(app)
        app.buttons[AccessibilityID.Collections.row(.throwaways)].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.CollectionSettings.keepScansFor].waitForExistence(timeout: 5))
        try audit(app)
    }

    // MARK: Steps

    private func openSettings(in app: XCUIApplication) {
        let gear = app.buttons[AccessibilityID.Home.settings]
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        XCTAssertEqual(gear.label, "Settings")
        gear.tap()
        assertIdentifiers(AccessibilityID.Settings.all + [AccessibilityID.Grid.back], in: app)
    }

    /// Back to Home, reads the number on the Trash row, and opens the screen again: Settings, Collections, Receipts.
    private func trashCount(in app: XCUIApplication) -> Int {
        let back = app.buttons[AccessibilityID.Grid.back]
        for _ in 0..<3 { back.tap() }
        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        XCTAssertTrue(trashRow.waitForExistence(timeout: 5))
        // "Trash, 2"; an empty Trash shows no number.
        let count = Int(trashRow.label.filter(\.isNumber)) ?? 0
        app.buttons[AccessibilityID.Home.settings].tap()
        app.buttons[AccessibilityID.Settings.collections].tap()
        app.buttons[AccessibilityID.Collections.row(.receipts)].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.CollectionSettings.keepScansFor].waitForExistence(timeout: 5))
        return count
    }

    private func menuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func waitFor(_ element: XCUIElement, value: String) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter.wait(for: [matches], timeout: 5) == .completed
    }

    /// Menus and alerts are never snapshotted: a screenshot is kept for review instead.
    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
