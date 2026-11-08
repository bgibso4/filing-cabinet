import Core
import XCTest

/// Details over the viewer: rename, a collection move with Undo, and an expiry choice. Menus are never snapshotted, so
/// the expiry menu is attached as a screenshot.
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
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "details-expiry-menu"
        shot.lifetime = .keepAlways
        add(shot)
        year.tap()
        XCTAssertTrue(waitFor(expiry, valuePrefix: "Oct "))

        // Close: the pill comes back with the new title.
        app.swipeDownOnSheet()
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertEqual(header.label, "Groceries, details")
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
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let tiles = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 5))
        tiles.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForExistence(timeout: 5))
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
