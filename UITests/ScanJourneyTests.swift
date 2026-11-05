import Core
import XCTest

/// Scan → review → save or discard, with the fake camera (M16). All but the last use the fake reader.
@MainActor
final class ScanJourneyTests: XCTestCase {
    private typealias Review = AccessibilityID.Review

    override func setUp() {
        continueAfterFailure = false
    }

    func testScanReviewSaveShowsOnHome() throws {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)
        assertIdentifiers(Review.all, in: app)
        let save = app.buttons[Review.save]
        XCTAssertFalse(save.isEnabled)
        try audit(app)

        app.descendants(matching: .any)[Review.collection].tap()
        let receipts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts'")).firstMatch
        XCTAssertTrue(receipts.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "collection-menu")
        receipts.tap()

        let expiry = app.descendants(matching: .any)[Review.expiry]
        let filledIn = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "3 months · until Jan 9, 2027"), object: expiry)
        XCTAssertEqual(XCTWaiter.wait(for: [filledIn], timeout: 5), .completed, String(describing: expiry.value))
        expiry.tap()
        let collectionDefault = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts default'"))
            .firstMatch
        XCTAssertTrue(collectionDefault.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "expiry-menu")
        collectionDefault.tap()

        XCTAssertTrue(save.isEnabled)
        XCTAssertEqual(save.label, "Save to Receipts")
        save.tap()

        let receiptsRow = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(receiptsRow.waitForExistence(timeout: 10))
        XCTAssertTrue(receiptsRow.label.contains("1"), receiptsRow.label)
    }

    func testChooseADateSetsExpiry() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        app.descendants(matching: .any)[Review.collection].tap()
        let receipts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts'")).firstMatch
        XCTAssertTrue(receipts.waitForExistence(timeout: 5))
        receipts.tap()
        let expiry = app.descendants(matching: .any)[Review.expiry]
        let collectionDefault = "3 months · until Jan 9, 2027"
        waitForValue(collectionDefault, of: expiry)

        // Cancel keeps the collection's default.
        openChooseADate(in: app)
        // Not assertIdentifiers: the system calendar's own buttons (month, days) carry no identifiers, as an alert's
        // don't. Ours are all there.
        for id in AccessibilityID.ExpiryDate.all {
            XCTAssertTrue(app.descendants(matching: .any)[id].exists, id)
        }
        app.buttons[AccessibilityID.ExpiryDate.cancel].tap()
        waitForValue(collectionDefault, of: expiry)

        // Done keeps the scan until the chosen day.
        openChooseADate(in: app)
        let day = app.descendants(matching: .any)[AccessibilityID.ExpiryDate.picker]
            .buttons.matching(NSPredicate(format: "label CONTAINS 'October 20'")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        app.buttons[AccessibilityID.ExpiryDate.done].tap()
        waitForValue("Until Oct 20", of: expiry)
    }

    func testReviewAuditAtLargestText() throws {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"], largestText: true)
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)
        XCTAssertTrue(app.buttons[Review.save].isHittable)
        attachScreenshot(of: app, named: "review-sheet-ax")
        try audit(app)
    }

    func testDiscardAsksFirst() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader"])
        scanOnePage(in: app)

        app.buttons[Review.close].tap()
        let alert = app.alerts["Discard this scan?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["The page you just scanned won’t be saved."].exists)
        attachScreenshot(of: app, named: "discard-alert")

        alert.buttons["Keep editing"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons[Review.save].exists)

        app.buttons[Review.close].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Discard"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[Review.save].exists)
    }

    func testRescanCancelKeepsTitle() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)

        app.buttons[Review.rescan].tap()
        let cancel = app.buttons[AccessibilityID.Camera.fakeCancel]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        waitForTitle("City Pharmacy", in: app)
        XCTAssertEqual(app.descendants(matching: .any)[Review.pagePill].label, "New scan, 1 page")
    }

    func testFailedSaveOffersTryAgain() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-FailSave"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)
        app.descendants(matching: .any)[Review.collection].tap()
        let receipts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts'")).firstMatch
        XCTAssertTrue(receipts.waitForExistence(timeout: 5))
        receipts.tap()
        app.buttons[Review.save].tap()

        let alert = app.alerts["Couldn’t save this scan"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.buttons["Not now"].exists)
        attachScreenshot(of: app, named: "save-failed-alert")
        alert.buttons["Try again"].tap()

        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.collectionRow(.receipts)].label.contains("1"))
    }

    /// The real Vision reader on the synthetic receipt. 90 s covers Vision's cold start on a CI simulator; if this
    /// proves flaky, raise it rather than widening the wait.
    func testRealVisionReadsTheTitle() {
        let app = launchApp(["-FakeCamera", "1"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app, timeout: 90)
    }

    // MARK: Helpers

    /// Taps Scan once launch has enabled it, then Finish on the fake camera, and waits for review.
    private func scanOnePage(in app: XCUIApplication) {
        let scan = app.buttons[AccessibilityID.Home.scan]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: scan)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        scan.tap()
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(app.buttons[Review.save].waitForExistence(timeout: 5))
    }

    /// Opens Expiry, then "Choose a date…", and waits for the calendar.
    private func openChooseADate(in app: XCUIApplication) {
        app.descendants(matching: .any)[Review.expiry].tap()
        let chooseDate = app.buttons["Choose a date…"]
        XCTAssertTrue(chooseDate.waitForExistence(timeout: 5))
        chooseDate.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.ExpiryDate.done].waitForExistence(timeout: 5))
    }

    private func waitForValue(_ value: String, of element: XCUIElement, line: UInt = #line) {
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [shown], timeout: 5), .completed, String(describing: element.value), line: line)
    }

    private func waitForTitle(
        _ title: String, in app: XCUIApplication, timeout: TimeInterval = 10, line: UInt = #line
    ) {
        let field = app.descendants(matching: .any)[Review.titleField]
        let read = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [read], timeout: timeout), .completed, "title", line: line)
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
