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

        waitForSaveToReturnHome(in: app)
    }

    /// The whole of Plan 1: a three-page scan is read, filed under Documents, found there and paged through.
    func testScanToViewer() throws {
        let app = launchApp(["-FakeCamera", "3", "-FakeReader", "-FixedDate", "2026-10-12"])
        try audit(app)
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)
        XCTAssertEqual(app.descendants(matching: .any)[Review.pagePill].label, "New scan, Page 1 of 3")
        XCTAssertEqual(app.descendants(matching: .any)[Review.strip].label, "Page 1 of 3")
        choose("Documents", in: app)
        assertIdentifiers(Review.all, in: app)
        try audit(app)
        let save = app.buttons[Review.save]
        XCTAssertEqual(save.label, "Save to Documents")
        save.tap()
        waitForSaveToReturnHome(in: app, collection: .documents)

        let row = app.buttons[AccessibilityID.Home.collectionRow(.documents)]
        row.tap()
        let header = app.descendants(matching: .any)[AccessibilityID.Grid.header]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        assertIdentifiers(AccessibilityID.Grid.all, in: app)
        try audit(app)
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForExistence(timeout: 5))
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)
        try audit(app)
        let strip = app.descendants(matching: .any)[AccessibilityID.Viewer.strip]
        for page in 2...3 {
            app.windows.firstMatch.swipeLeft()
            let shown = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Page \(page) of 3"), object: strip)
            XCTAssertEqual(
                XCTWaiter.wait(for: [shown], timeout: 5), .completed, String(describing: strip.label))
        }

        app.buttons[AccessibilityID.Viewer.back].tap()
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        app.buttons[AccessibilityID.Grid.back].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.collectionRow(.documents)].isHittable)
    }

    func testSaveReturnsHomeAndCountTicks() {
        saveReceiptFromHome()
    }

    /// A second scan after a save opens a camera on screen (regression: the slide-away stayed applied, so the next
    /// camera opened off screen, a black screen on Ben's phone).
    func testSecondScanAfterASaveShowsTheCamera() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        chooseReceipts(in: app)
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        waitForSaveToReturnHome(in: app)

        app.buttons[AccessibilityID.Home.scan].tap()
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        XCTAssertTrue(finish.isHittable, "the second camera is off screen")
    }

    /// Saved inside Receipts, the layer slides back to the grid, which shows the new tile.
    func testSaveInsideItsCollectionEndsOnTheGrid() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        saveFromInsideReceipts(in: app, choosing: nil)
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
        XCTAssertTrue(tile.firstMatch.waitForExistence(timeout: 5))
        // Scan answers again, on the same grid.
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].exists)
        app.buttons[AccessibilityID.Grid.back].tap()
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("1"), row.label)
    }

    /// Scanned in Receipts, saved to Wallet: Wallet's count is on Home.
    func testSaveToAnotherCollectionFromAGridCountsOnHome() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        saveFromInsideReceipts(in: app, choosing: "Wallet")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
        app.buttons[AccessibilityID.Grid.back].tap()
        waitForSaveToReturnHome(in: app, collection: .wallet)
    }

    /// Scrolled far down a grid, the new tile isn't on screen: the layer ends, Scan is back and the grid stays where it
    /// was.
    func testSaveWithTheTileScrolledAwayKeepsTheScroll() {
        let app = launchApp(["-SeedScans", "60", "-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        // Scan stays disabled until all sixty are saved, which takes most of a minute on a busy machine. Waiting here
        // also means the grid has stopped growing before it is scrolled.
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"), object: app.buttons[AccessibilityID.Home.scan])
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 120), .completed)
        let all = app.buttons[AccessibilityID.Home.allRow]
        XCTAssertTrue(all.waitForExistence(timeout: 30))
        all.tap()
        let header = app.descendants(matching: .any)[AccessibilityID.Grid.header]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        XCTAssertFalse(header.isHittable)
        finishCameraFromGrid(in: app)
        chooseReceipts(in: app)
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.scan].waitForExistence(timeout: 5))
        XCTAssertFalse(header.isHittable)
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
        XCTAssertTrue(app.buttons[Review.save].waitForNonExistence(timeout: 5))
        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        XCTAssertTrue(scan.isHittable)
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

        waitForSaveToReturnHome(in: app)
    }

    /// The real Vision reader on the synthetic receipt. 90 s covers Vision's cold start on a CI simulator; if this
    /// proves flaky, raise it rather than widening the wait.
    func testRealVisionReadsTheTitle() {
        let app = launchApp(["-FakeCamera", "1"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app, timeout: 90)
    }

}

// MARK: Helpers

/// Kept out of the class body so it stays under the type length limit.
extension ScanJourneyTests {
    private func saveReceiptFromHome() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        chooseReceipts(in: app)
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        waitForSaveToReturnHome(in: app)
    }

    /// Opens Receipts, scans there and saves, optionally to another collection.
    private func saveFromInsideReceipts(in app: XCUIApplication, choosing other: String?) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
        finishCameraFromGrid(in: app)
        if let other {
            app.descendants(matching: .any)[Review.collection].tap()
            let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", other)).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
        }
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    }

    private func finishCameraFromGrid(in app: XCUIApplication) {
        let scan = app.buttons[AccessibilityID.Grid.scan]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        scan.tap()
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        // The grid under the camera is out of the tree too, its Scan bar included.
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.scan].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Grid.header].exists)
        finish.tap()
        XCTAssertTrue(app.buttons[Review.save].waitForExistence(timeout: 5))
    }

    func chooseReceipts(in app: XCUIApplication) {
        choose("Receipts", in: app)
    }

    /// Opens the collection menu on review and picks the named collection.
    private func choose(_ collection: String, in app: XCUIApplication) {
        app.descendants(matching: .any)[Review.collection].tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", collection)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
    }

    /// The layer is gone and Home shows the collection's new count.
    private func waitForSaveToReturnHome(
        in app: XCUIApplication, collection: BuiltInCollection = .receipts, line: UInt = #line
    ) {
        // Home stays in the tree under the capture layer, so its own elements say nothing about the layer being gone.
        XCTAssertTrue(app.buttons[Review.save].waitForNonExistence(timeout: 10), line: line)
        let row = app.buttons[AccessibilityID.Home.collectionRow(collection)]
        XCTAssertTrue(row.waitForExistence(timeout: 5), line: line)
        let counted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '1'"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [counted], timeout: 5), .completed, row.label, line: line)
        XCTAssertTrue(row.isHittable, line: line)
    }

    /// Taps Scan once launch has enabled it, then Finish on the fake camera, and waits for review.
    func scanOnePage(in app: XCUIApplication) {
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
