import Core
import XCTest

/// Details over the viewer: rename, a collection move with Undo, an expiry choice, and the moves into Trash from the
/// viewer and from Details. Menus, dialogs and alerts are never snapshotted, so they are attached as screenshots.
@MainActor
final class DetailsJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func seededApp(largestText: Bool = false) -> XCUIApplication {
        launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12", "-FakeReader"], largestText: largestText)
    }

    func testRenameMoveUndoAndExpiry() throws {
        let app = seededApp()
        openAReceipt(in: app)
        assertIdentifiers(AccessibilityID.Viewer.all.filter { $0 != AccessibilityID.Viewer.strip }, in: app)
        openDetails(in: app)
        try audit(app)

        // Rename: tap the title, clear it, type, Return.
        app.buttons[AccessibilityID.Details.title].tap()
        let field = app.textFields[AccessibilityID.Details.titleField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Not `assertIdentifiers`: with the keyboard up the tree holds the system keyboard's own buttons, which have no
        // identifiers ("Continue" on its first-use tip).
        XCTAssertTrue(app.buttons[AccessibilityID.Details.clearTitle].exists)
        app.buttons[AccessibilityID.Details.clearTitle].tap()
        field.typeText("Groceries\n")
        let title = app.buttons[AccessibilityID.Details.title]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Rename Groceries")

        // Move to Documents: the note and Undo.
        choose("Documents", from: AccessibilityID.Details.collection, in: app)
        let collection = app.descendants(matching: .any)[AccessibilityID.Details.collection]
        XCTAssertTrue(waitFor(collection, value: "Documents"))
        XCTAssertTrue(app.staticTexts["Expiry now follows Documents."].waitForExistence(timeout: 5))
        assertIdentifiers(
            AccessibilityID.Details.all.filter { $0 != AccessibilityID.Details.titleField }, in: app)
        app.buttons[AccessibilityID.Details.undo].tap()
        XCTAssertTrue(waitFor(collection, value: "Receipts"))
        XCTAssertFalse(app.buttons[AccessibilityID.Details.undo].exists)

        // Expiry: 1 year from the scan date.
        let expiry = app.descendants(matching: .any)[AccessibilityID.Details.expiry]
        expiry.tap()
        let year = menuItem("1 year", in: app)
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        attachScreenshot("details-expiry-menu", of: app)
        year.tap()
        XCTAssertTrue(waitFor(expiry, valuePrefix: "Oct "))

        // Close: the pill comes back with the new title.
        app.swipeDownOnSheet()
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertEqual(header.label, "Groceries, details")
    }

    /// 06-04: Trash asks in a popover from the button; Move to Trash pops back to a grid with one fewer tile.
    func testMoveToTrashFromTheViewer() {
        let app = seededApp()
        openReceipts(in: app)
        let before = tiles(in: app).count
        tiles(in: app).firstMatch.tap()
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.waitForExistence(timeout: 5))

        app.buttons[AccessibilityID.Viewer.trash].tap()
        // The Trash button is labelled Move to Trash too.
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Viewer.trash)
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This receipt moves to Trash. You can restore it for 30 days."].exists)
        attachScreenshot("viewer-move-to-trash", of: app)
        confirm.tap()

        XCTAssertTrue(header.waitForNonExistence(timeout: 5))
        XCTAssertTrue(waitFor(tiles(in: app), count: before - 1))
    }

    /// 07-07: moving an 11-day-old receipt to Throwaways (kept 1 week) asks first; Move closes the sheet and pops.
    func testMovingToThrowawaysAsksFirst() {
        let app = seededApp()
        openReceipts(in: app)
        let before = tiles(in: app).count
        // Seed index 11: the oldest receipt.
        let old = tiles(in: app).matching(NSPredicate(format: "label BEGINSWITH %@", "Sample scan 12,")).firstMatch
        XCTAssertTrue(old.waitForExistence(timeout: 5))
        old.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForExistence(timeout: 5))
        openDetails(in: app)

        choose("Throwaways", from: AccessibilityID.Details.collection, in: app)
        let alert = app.alerts["Move to Throwaways?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        attachScreenshot("details-move-to-throwaways", of: app)
        alert.buttons["Move"].tap()

        let sheet = app.descendants(matching: .any)[AccessibilityID.Details.sheet]
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor(tiles(in: app), count: before - 1))
    }

    func testAuditAtLargestTextDetails() throws {
        let app = seededApp(largestText: true)
        openAReceipt(in: app)
        openDetails(in: app)
        try audit(app)
    }

    // MARK: Steps

    /// The seed's newest Receipts scan, one page.
    private func openAReceipt(in app: XCUIApplication) {
        openReceipts(in: app)
        tiles(in: app).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForExistence(timeout: 5))
    }

    /// The Receipts grid, newest first.
    private func openReceipts(in app: XCUIApplication) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(tiles(in: app).firstMatch.waitForExistence(timeout: 5))
    }

    private func tiles(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
    }

    /// Dialogs and alerts are never snapshotted: a screenshot is kept for review instead.
    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The header pill opens Details, and the pill makes way for it.
    private func openDetails(in app: XCUIApplication) {
        app.descendants(matching: .any)[AccessibilityID.Viewer.header].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Details.title].waitForExistence(timeout: 5))
        assertIdentifiers(
            [
                AccessibilityID.Details.sheet, AccessibilityID.Details.title, AccessibilityID.Details.collection,
                AccessibilityID.Details.expiry,
            ], in: app)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Viewer.header].exists)
    }

    private func choose(_ item: String, from menu: String, in app: XCUIApplication) {
        app.descendants(matching: .any)[menu].tap()
        let button = menuItem(item, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 5), item)
        button.tap()
    }

    /// A menu item's label carries its subtitle too ("1 year, Oct 10, 2027").
    private func menuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func waitFor(_ element: XCUIElement, value: String) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter.wait(for: [matches], timeout: 5) == .completed
    }

    private func waitFor(_ query: XCUIElementQuery, count: Int) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        return XCTWaiter.wait(for: [matches], timeout: 5) == .completed
    }

    private func waitFor(_ element: XCUIElement, valuePrefix: String) -> Bool {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value BEGINSWITH %@", valuePrefix), object: element)
        return XCTWaiter.wait(for: [matches], timeout: 5) == .completed
    }
}

extension XCUIApplication {
    /// Drags the sheet's grabber down until the sheet closes.
    @MainActor
    fileprivate func swipeDownOnSheet() {
        let sheet = descendants(matching: .any)[AccessibilityID.Details.sheet]
        let top = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        top.press(
            forDuration: 0.05, thenDragTo: windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
        )
    }
}
