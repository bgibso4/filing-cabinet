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

    /// Renaming ends with a tap outside the field, as Return does: on the page above the panel (which doesn't close
    /// Details), or on the panel around the field. A tap on the field itself keeps renaming.
    func testATapOutsideTheFieldEndsRenaming() {
        let app = seededApp()
        openAReceipt(in: app)
        openDetails(in: app)
        let title = app.buttons[AccessibilityID.Details.title]
        let field = app.textFields[AccessibilityID.Details.titleField]

        title.tap()
        XCTAssertTrue(app.keyboards.firstMatch.appears(within: 5))
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists, "A tap on the field ended renaming")
        app.buttons[AccessibilityID.Details.clearTitle].tap()
        field.typeText("Groceries")
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(title.appears(within: 5))
        XCTAssertEqual(title.label, "Rename Groceries")
        XCTAssertTrue(app.keyboards.firstMatch.disappears(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.sheet].exists, "Details closed")

        // On the panel, under the field: the hint.
        title.tap()
        XCTAssertTrue(field.appears(within: 5))
        field.typeText(" list")
        app.staticTexts["Suggested from the scan’s text. Search finds it by title and text."].tap()
        XCTAssertTrue(title.appears(within: 5))
        XCTAssertEqual(title.label, "Rename Groceries list")
        XCTAssertTrue(app.keyboards.firstMatch.disappears(within: 5))
    }

    /// Info opens Details over the pill, and dragging it down brings the pill back (#61).
    func testInfoOpensAndClosesDetails() {
        let app = seededApp()
        openAReceipt(in: app)
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.isHittable)

        app.buttons[AccessibilityID.Viewer.details].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.sheet].appears(within: 5))
        // Faded out, and out of VoiceOver's way, so nothing can reach it.
        XCTAssertTrue(header.disappears(within: 5))

        app.swipeDownOnSheet()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.sheet].disappears(within: 5))
        XCTAssertTrue(header.satisfies("exists == true AND hittable == true", within: 5))
    }

    /// A swipe up on the page raises Details under the finger, and a drag down on its grabber closes it (#61, B10).
    func testSwipeUpOpensDetailsAndSwipeDownCloses() {
        let app = seededApp()
        openAReceipt(in: app)
        let centre = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: 0, dy: -300)))
        let sheet = app.descendants(matching: .any)[AccessibilityID.Details.sheet]
        XCTAssertTrue(sheet.appears(within: 5))
        // Fully up once the pill has left: the sheet's frame is where it rests, not where it is mid-motion.
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.disappears(within: 5))

        app.swipeDownOnSheet()
        XCTAssertTrue(sheet.disappears(within: 5))
        XCTAssertTrue(header.satisfies("exists == true AND hittable == true", within: 5))
    }

    /// With Details up, a swipe down on the page closes it, like Photos (#71); zoomed in, the same swipe pans the page
    /// and Details stays.
    func testASwipeDownOnThePageClosesDetailsUnlessZoomed() {
        let app = seededApp()
        openAReceipt(in: app)
        openDetails(in: app)
        let sheet = app.descendants(matching: .any)[AccessibilityID.Details.sheet]
        let page = app.descendants(matching: .any)[AccessibilityID.Viewer.page].firstMatch
        let swipeDown = {
            let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 300)))
        }

        page.doubleTap()
        XCTAssertTrue(page.satisfies("value == %@", "Zoomed", within: 5), "The page never reported being zoomed")
        swipeDown()
        XCTAssertTrue(sheet.exists, "A drag on a zoomed page closed Details")
        page.doubleTap()
        XCTAssertTrue(page.satisfies("value != %@", "Zoomed", within: 5), "The page never zoomed back out")

        swipeDown()
        XCTAssertTrue(sheet.disappears(within: 5))
    }

    /// At the largest text, after a move, Details is taller than the screen. Its body scrolls first, as Apple's sheets
    /// do: up, Undo comes into reach; down while scrolled, it scrolls back and the panel stays. The grabber always drags
    /// the panel.
    func testTheBodyScrollsBeforeThePanelMovesAtTheLargestText() {
        let app = seededApp(largestText: true)
        openAReceipt(in: app)
        openDetails(in: app)
        choose("Documents", from: AccessibilityID.Details.collection, in: app)
        let undo = app.buttons[AccessibilityID.Details.undo]
        XCTAssertTrue(undo.appears(within: 5))
        let sheet = app.descendants(matching: .any)[AccessibilityID.Details.sheet]
        XCTAssertGreaterThan(
            undo.frame.maxY, sheet.frame.maxY, "Undo should start cut off by the panel, or this test proves nothing")

        // Scrolled up, Undo comes fully into the panel, which stays up: the pill only comes back once Details drops.
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        let body = app.buttons[AccessibilityID.Details.title].coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        body.press(forDuration: 0.05, thenDragTo: body.withOffset(CGVector(dx: 0, dy: -400)))
        XCTAssertLessThanOrEqual(undo.frame.maxY, sheet.frame.maxY)
        XCTAssertTrue(undo.isHittable)
        XCTAssertFalse(header.exists)

        // Dragged down while scrolled, the body scrolls back rather than the panel moving.
        let middle = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 200)))
        XCTAssertTrue(sheet.exists)
        XCTAssertFalse(header.exists)
        XCTAssertGreaterThan(undo.frame.maxY, sheet.frame.maxY)

        app.swipeDownOnSheet()
        XCTAssertTrue(sheet.disappears(within: 5))
    }

    /// At the largest text, after a move, the body scrolls; at its top, a drag down on it moves the panel and closes it,
    /// as Apple's sheets do.
    func testADragDownOnTheBodyAtItsTopClosesDetailsAtTheLargestText() {
        let app = seededApp(largestText: true)
        openAReceipt(in: app)
        openDetails(in: app)
        choose("Documents", from: AccessibilityID.Details.collection, in: app)
        let undo = app.buttons[AccessibilityID.Details.undo]
        XCTAssertTrue(undo.appears(within: 5))
        let sheet = app.descendants(matching: .any)[AccessibilityID.Details.sheet]
        XCTAssertGreaterThan(
            undo.frame.maxY, sheet.frame.maxY, "The body should overflow, or this test proves nothing")

        let middle = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        middle.press(
            forDuration: 0.05,
            thenDragTo: app.windows.firstMatch.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 1)))
        XCTAssertTrue(sheet.disappears(within: 5))
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
        XCTAssertTrue(app.header(.receipts).appears(within: 5))
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
        // The pill fades as Details rises, and leaves VoiceOver once it is up.
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].disappears(within: 5))
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
