import Core
import XCTest

/// Scan → review → save or discard, with the fake camera (M16). All but the last use the fake reader.
@MainActor
final class ScanJourneyTests: XCTestCase {
    private typealias Review = AccessibilityID.Review

    override func setUp() {
        continueAfterFailure = false
    }

    /// Scan doesn't wait for iOS to say whether notes may be sent (CI run 42752032236: Scan stayed disabled 5.5 s
    /// after a relaunch).
    func testScanIsReadyWhileNotificationsHaveNotAnswered() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-NotificationsUnanswered"])
        scanOnePage(in: app)
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
        XCTAssertTrue(receipts.appears(within: 5))
        attachScreenshot(of: app, named: "collection-menu")
        receipts.tap()

        let expiry = app.descendants(matching: .any)[Review.expiry]
        XCTAssertTrue(
            expiry.satisfies("value == %@", "3 months · until Jan 9, 2027", within: 5), String(describing: expiry.value)
        )
        expiry.tap()
        let collectionDefault = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts default'"))
            .firstMatch
        XCTAssertTrue(collectionDefault.appears(within: 5))
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
        let header = app.header(.documents)
        XCTAssertTrue(header.appears(within: 5))
        assertIdentifiers(AccessibilityID.Grid.all, in: app)
        try audit(app)
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        tile.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)
        try audit(app)
        let strip = app.descendants(matching: .any)[AccessibilityID.Viewer.strip]
        for page in 2...3 {
            app.windows.firstMatch.swipeLeft()
            XCTAssertTrue(
                strip.satisfies("label == %@", "Page \(page) of 3", within: 5), String(describing: strip.label))
        }

        app.buttons[AccessibilityID.Viewer.back].tap()
        XCTAssertTrue(header.appears(within: 5))
        app.buttons[AccessibilityID.Grid.back].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.collectionRow(.documents)].isHittable)
    }

    func testSaveReturnsHomeAndCountTicks() {
        saveReceiptFromHome()
    }

    /// Under Reduce Motion the layer fades, and the fade's end ends it: until then Home is out of the tree.
    func testSaveReturnsHomeWithReduceMotion() {
        saveReceiptFromHome(flags: ["-ReduceMotion"])
    }

    /// Apple limits how often its prompt shows, so it is dismissed if it does.
    func testRatingDueDoesNotDisturbTheSave() {
        saveReceiptFromHome(flags: ["-RatingDue"], dismissingRating: true)
    }

    /// Guards that a second scan after a save opens a camera on screen, so the slide-away never carries over to the
    /// next layer.
    func testSecondScanAfterASaveShowsTheCamera() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        chooseReceipts(in: app)
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.disappears(within: 10))
        waitForSaveToReturnHome(in: app)

        app.buttons[AccessibilityID.Home.scan].tap()
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.appears(within: 5))
        XCTAssertTrue(finish.isHittable, "the second camera is off screen")
    }

    /// Saved inside Receipts, the layer slides back to the grid, which shows the new tile.
    func testSaveInsideItsCollectionEndsOnTheGrid() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        saveFromInsideReceipts(in: app, choosing: nil)
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
        XCTAssertTrue(tile.firstMatch.appears(within: 5))
        // Scan answers again, on the same grid.
        XCTAssertTrue(app.header(.receipts).exists)
        app.buttons[AccessibilityID.Grid.back].tap()
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.appears(within: 5))
        XCTAssertTrue(row.label.contains("1"), row.label)
    }

    /// Scanned in Receipts, saved to Wallet: Wallet's count is on Home.
    func testSaveToAnotherCollectionFromAGridCountsOnHome() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        saveFromInsideReceipts(in: app, choosing: "Wallet")
        XCTAssertTrue(app.header(.receipts).appears(within: 5))
        app.buttons[AccessibilityID.Grid.back].tap()
        waitForSaveToReturnHome(in: app, collection: .wallet)
    }

    /// Scrolled far down a grid, the new tile isn't on screen: the layer ends, Scan is back and the grid stays where it
    /// was.
    func testSaveWithTheTileScrolledAwayKeepsTheScroll() {
        let app = launchApp(["-SeedScans", "60", "-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        // Scan stays disabled until all sixty are saved, which takes most of a minute on a busy machine. Waiting here
        // also means the grid has stopped growing before it is scrolled.
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isEnabled == true", within: 120))
        let all = app.buttons[AccessibilityID.Home.allRow]
        XCTAssertTrue(all.appears(within: 30))
        all.tap()
        XCTAssertTrue(app.header("All Scans").appears(within: 5))
        // The newest tile, first in the grid; scrolled off the top, it is no longer hittable.
        let first = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(first.appears(within: 5))
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        XCTAssertFalse(first.isHittable)
        finishCameraFromGrid(in: app)
        chooseReceipts(in: app)
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.disappears(within: 10))
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.scan].appears(within: 5))
        XCTAssertFalse(first.isHittable)
    }

    func testChooseADateSetsExpiry() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        app.descendants(matching: .any)[Review.collection].tap()
        let receipts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts'")).firstMatch
        XCTAssertTrue(receipts.appears(within: 5))
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
        XCTAssertTrue(day.appears(within: 5))
        day.tap()
        app.buttons[AccessibilityID.ExpiryDate.done].tap()
        waitForValue("Until Oct 20", of: expiry)
    }

    func testAuditAtLargestTextOfReview() throws {
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
        XCTAssertTrue(alert.appears(within: 5))
        XCTAssertTrue(alert.staticTexts["The page you just scanned won’t be saved."].exists)
        attachScreenshot(of: app, named: "discard-alert")

        alert.buttons["Keep editing"].tap()
        XCTAssertTrue(alert.disappears(within: 5))
        XCTAssertTrue(app.buttons[Review.save].exists)

        app.buttons[Review.close].tap()
        XCTAssertTrue(alert.appears(within: 5))
        alert.buttons["Discard"].tap()
        XCTAssertTrue(app.buttons[Review.save].disappears(within: 5))
        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.appears(within: 5))
        XCTAssertTrue(scan.isHittable)
    }

    func testRescanCancelKeepsTitle() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)

        app.buttons[Review.rescan].tap()
        let cancel = app.buttons[AccessibilityID.Camera.fakeCancel]
        XCTAssertTrue(cancel.appears(within: 5))
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
        XCTAssertTrue(receipts.appears(within: 5))
        receipts.tap()
        app.buttons[Review.save].tap()

        let alert = app.alerts["Couldn’t save this scan"]
        XCTAssertTrue(alert.appears(within: 10))
        XCTAssertTrue(alert.buttons["Not now"].exists)
        attachScreenshot(of: app, named: "save-failed-alert")
        alert.buttons["Try again"].tap()

        waitForSaveToReturnHome(in: app)
    }

    /// Plan 2 end to end: a saved receipt is renamed in Details, moved to Trash from the viewer, restored from Trash's
    /// viewer, and is back in Receipts kept forever (M10).
    func testScanEditTrashRestore() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)
        chooseReceipts(in: app)
        app.buttons[Review.save].tap()
        waitForSaveToReturnHome(in: app)

        openOnlyTile(of: .receipts, in: app)
        renameInDetails(to: "Groceries", in: app)
        moveToTrashFromTheViewer(in: app)
        restoreFromTrash("Groceries", in: app)

        // Back in Receipts, and the restore made it Forever.
        openOnlyTile(of: .receipts, in: app, label: ("Groceries, Receipts, ", ", Kept forever"))
    }

    /// The real Vision reader on the synthetic receipt (90 s covers a cold start on CI).
    func testRealVisionReadsTheTitle() {
        // A real launch: Vision's first read in a fresh process is the slow one this checks.
        let app = launchApp(["-FakeCamera", "1"], fresh: true)
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app, timeout: 90)
    }
}

// MARK: Helpers

/// Kept out of the class body so it stays under the type length limit.
extension ScanJourneyTests {
    private func saveReceiptFromHome(flags: [String] = [], dismissingRating: Bool = false) {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"] + flags)
        scanOnePage(in: app)
        chooseReceipts(in: app)
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.disappears(within: 10))
        if dismissingRating { dismissRatingPrompt(in: app) }
        waitForSaveToReturnHome(in: app)
    }

    /// Opens Receipts, scans there and saves, optionally to another collection.
    private func saveFromInsideReceipts(in app: XCUIApplication, choosing other: String?) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.appears(within: 5))
        row.tap()
        XCTAssertTrue(app.header(.receipts).appears(within: 5))
        finishCameraFromGrid(in: app)
        if let other {
            app.descendants(matching: .any)[Review.collection].tap()
            let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", other)).firstMatch
            XCTAssertTrue(option.appears(within: 5))
            option.tap()
        }
        let save = app.buttons[Review.save]
        save.tap()
        XCTAssertTrue(save.disappears(within: 10))
    }

    private func finishCameraFromGrid(in app: XCUIApplication) {
        let scan = app.buttons[AccessibilityID.Grid.scan]
        XCTAssertTrue(scan.appears(within: 5))
        scan.tap()
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.appears(within: 5))
        // The grid under the camera is out of the tree too, its Scan bar included.
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.scan].disappears(within: 5))
        XCTAssertFalse(app.header(.receipts).exists)
        finish.tap()
        XCTAssertTrue(app.buttons[Review.save].appears(within: 5))
    }

    func chooseReceipts(in app: XCUIApplication) {
        choose("Receipts", in: app)
    }

    /// Opens the collection menu on review and picks the named collection.
    private func choose(_ collection: String, in app: XCUIApplication) {
        app.descendants(matching: .any)[Review.collection].tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", collection)).firstMatch
        XCTAssertTrue(option.appears(within: 5))
        option.tap()
    }

    /// The layer is gone and Home shows the collection's new count.
    private func waitForSaveToReturnHome(
        in app: XCUIApplication, collection: BuiltInCollection = .receipts, line: UInt = #line
    ) {
        // Home stays in the tree under the capture layer, so its own elements say nothing about the layer being gone.
        XCTAssertTrue(app.buttons[Review.save].disappears(within: 10), line: line)
        // One predicate for both, so each check is one read of the screen: a read alone can take 4 s on CI.
        let row = app.buttons[AccessibilityID.Home.collectionRow(collection)]
        XCTAssertTrue(row.satisfies("exists == true AND label CONTAINS '1'", within: 5), row.label, line: line)
        XCTAssertTrue(row.satisfies("isHittable == true", within: 5), line: line)
    }

    /// Opens Expiry, then "Choose a date…", and waits for the calendar.
    private func openChooseADate(in app: XCUIApplication) {
        app.descendants(matching: .any)[Review.expiry].tap()
        let chooseDate = app.buttons["Choose a date…"]
        XCTAssertTrue(chooseDate.appears(within: 5))
        chooseDate.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.ExpiryDate.done].appears(within: 5))
    }

    private func waitForValue(_ value: String, of element: XCUIElement, line: UInt = #line) {
        XCTAssertTrue(element.satisfies("value == %@", value, within: 5), String(describing: element.value), line: line)
    }

    private func waitForTitle(
        _ title: String, in app: XCUIApplication, timeout: TimeInterval = 10, line: UInt = #line
    ) {
        let field = app.descendants(matching: .any)[Review.titleField]
        XCTAssertTrue(field.satisfies("value == %@", title, within: timeout), "title", line: line)
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
