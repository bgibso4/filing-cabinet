import Core
import XCTest

/// Details over the viewer: rename, a collection move with Undo, an expiry choice, and the moves into Trash from the
/// viewer and from Details. Menus, dialogs and alerts are never snapshotted, so they are attached as screenshots.
@MainActor
final class DetailsJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Twelve scans dated 0 to 11 days ago, three of them Receipts (1, 6 and 11 days old). Seeding ends after Home
    /// shows, so this waits for all three before a test counts the Receipts grid.
    private func seededApp(largestText: Bool = false) -> XCUIApplication {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12", "-FakeReader"], largestText: largestText)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 3)
        return app
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
        XCTAssertTrue(field.appears(within: 5))
        // Not `assertIdentifiers`: with the keyboard up the tree holds the system keyboard's own buttons, which have no
        // identifiers ("Continue" on its first-use tip).
        XCTAssertTrue(app.buttons[AccessibilityID.Details.clearTitle].exists)
        app.buttons[AccessibilityID.Details.clearTitle].tap()
        field.typeText("Groceries\n")
        let title = app.buttons[AccessibilityID.Details.title]
        XCTAssertTrue(title.appears(within: 5))
        XCTAssertEqual(title.label, "Rename Groceries")

        // Move to Documents: the note and Undo.
        choose("Documents", from: AccessibilityID.Details.collection, in: app)
        let collection = app.descendants(matching: .any)[AccessibilityID.Details.collection]
        XCTAssertTrue(waitFor(collection, value: "Documents"))
        XCTAssertTrue(app.staticTexts["Expiry now follows Documents."].appears(within: 5))
        assertIdentifiers(
            AccessibilityID.Details.all.filter { $0 != AccessibilityID.Details.titleField }, in: app)
        app.buttons[AccessibilityID.Details.undo].tap()
        XCTAssertTrue(waitFor(collection, value: "Receipts"))
        XCTAssertFalse(app.buttons[AccessibilityID.Details.undo].exists)

        // Expiry: 1 year from the scan date.
        let expiry = app.descendants(matching: .any)[AccessibilityID.Details.expiry]
        expiry.tap()
        let year = menuItem("1 year", in: app)
        XCTAssertTrue(year.appears(within: 5))
        attachScreenshot("details-expiry-menu", of: app)
        year.tap()
        XCTAssertTrue(waitFor(expiry, valuePrefix: "Oct "))

        // Close: the pill comes back with the new title.
        app.swipeDownOnSheet()
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.appears(within: 5))
        XCTAssertEqual(header.label, "Groceries, details")
    }

    /// 06-04: Trash asks in a popover from the button; Move to Trash pops back to a grid with one fewer tile.
    func testMoveToTrashFromTheViewer() {
        let app = seededApp()
        openReceipts(in: app)
        let before = tiles(in: app).count
        tiles(in: app).firstMatch.tap()
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.appears(within: 5))

        app.buttons[AccessibilityID.Viewer.trash].tap()
        // The Trash button is labelled Move to Trash too.
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Viewer.trash)
        ).firstMatch
        XCTAssertTrue(confirm.appears(within: 5))
        XCTAssertTrue(app.staticTexts["This receipt moves to Trash. You can restore it for 30 days."].exists)
        attachScreenshot("viewer-move-to-trash", of: app)
        confirm.tap()

        XCTAssertTrue(header.disappears(within: 5))
        XCTAssertTrue(waitFor(tiles(in: app), count: before - 1))
    }

    /// 07-07: moving an 11-day-old receipt to Throwaways (kept 1 week) asks first; Move closes the sheet and pops.
    func testMovingToThrowawaysAsksFirst() {
        let app = seededApp()
        openReceipts(in: app)
        let before = tiles(in: app).count
        // Seed index 11: the oldest receipt.
        let old = tiles(in: app).matching(NSPredicate(format: "label BEGINSWITH %@", "Sample scan 12,")).firstMatch
        XCTAssertTrue(old.appears(within: 5))
        old.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
        openDetails(in: app)

        choose("Throwaways", from: AccessibilityID.Details.collection, in: app)
        let alert = app.alerts["Move to Throwaways?"]
        XCTAssertTrue(alert.appears(within: 5))
        attachScreenshot("details-move-to-throwaways", of: app)
        alert.buttons["Move"].tap()

        let sheet = app.descendants(matching: .any)[AccessibilityID.Details.sheet]
        XCTAssertTrue(sheet.disappears(within: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityID.Viewer.header].disappears(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].appears(within: 5))
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
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
    }

    /// The Receipts grid, newest first.
    private func openReceipts(in app: XCUIApplication) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.appears(within: 5))
        row.tap()
        XCTAssertTrue(tiles(in: app).firstMatch.appears(within: 5))
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
        XCTAssertTrue(app.buttons[AccessibilityID.Details.title].appears(within: 5))
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
        XCTAssertTrue(button.appears(within: 5), item)
        button.tap()
    }

    /// A menu item's label carries its subtitle too ("1 year, Oct 10, 2027").
    private func menuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func waitFor(_ element: XCUIElement, value: String) -> Bool {
        element.satisfies("value == %@", value, within: 5)
    }

    private func waitFor(_ query: XCUIElementQuery, count: Int) -> Bool {
        query.satisfies("count == %d", count, within: 5)
    }

    private func waitFor(_ element: XCUIElement, valuePrefix: String) -> Bool {
        element.satisfies("value BEGINSWITH %@", valuePrefix, within: 5)
    }
}
