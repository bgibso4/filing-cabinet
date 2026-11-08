import Core
import XCTest

/// Trash from Home's Trash row: a long press restores one, Select deletes two, Empty Trash deletes the rest, and a scan
/// opened from Trash restores itself. Menus and alerts are never snapshotted, so they are attached as screenshots.
@MainActor
final class TrashJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Seeding 11 scans takes about 3.1 s on a Mac after the launch returns (measured 2026-11-08); a CI runner is
    /// several times slower, so the usual 5 s is not enough to wait for it.
    private static let seedingTimeout: TimeInterval = 15

    /// Six scans in the library and five in Trash, moved there 0 to 4 days ago.
    ///
    /// Home shows before seeding ends: the Trash row is there once the library has scans, and reads "Trash" with no
    /// number until the last seeded scan has moved to Trash. So this waits for the 5, which also means every other row
    /// has its final count. Reading the label as soon as the row exists raced the seeding (CI, run 42479032879).
    private func seededApp(largestText: Bool = false) -> XCUIApplication {
        let app = launchApp(
            ["-SeedScans", "6", "-SeedTrash", "5", "-FixedDate", "2026-10-12"], largestText: largestText)
        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        // "Trash, 5"; at accessibility sizes the count sits above the name and reads first.
        let seeded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", "5"), object: trashRow)
        let result = XCTWaiter.wait(for: [seeded], timeout: Self.seedingTimeout)
        XCTAssertEqual(result, .completed, "Trash never showed its 5 seeded scans")
        return app
    }

    func testRestoreSelectDeleteAndEmpty() throws {
        let app = seededApp()
        openTrash(in: app)
        XCTAssertTrue(waitFor(tiles(in: app), count: 5))
        assertIdentifiers(
            [
                AccessibilityID.Grid.back, AccessibilityID.Trash.header, AccessibilityID.Trash.select,
                AccessibilityID.Trash.emptyTrash,
            ], in: app)
        // Soonest gone first: the scan moved 4 days ago has 26 days left.
        XCTAssertEqual(tiles(in: app).firstMatch.label, "Trashed scan 5, Throwaways, 26 days left")
        try audit(app)

        try restoreByLongPress(in: app)
        try deleteTwoBySelecting(in: app)
        try emptyTrash(in: app)

        // Home: the restored scan is back in Throwaways, and Trash shows no number.
        app.buttons[AccessibilityID.Grid.back].tap()
        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        XCTAssertTrue(trashRow.waitForExistence(timeout: 5))
        XCTAssertEqual(trashRow.label, "Trash")
        XCTAssertEqual(app.buttons[AccessibilityID.Home.collectionRow(.throwaways)].label, "Throwaways, 2")
    }

    func testAuditAtLargestTextTrash() throws {
        let app = seededApp(largestText: true)
        openTrash(in: app)
        XCTAssertTrue(waitFor(tiles(in: app), count: 5))
        try audit(app)
    }

    func testAuditAtLargestTextTrashViewer() throws {
        let app = seededApp(largestText: true)
        openTrash(in: app)
        XCTAssertTrue(waitFor(tiles(in: app), count: 5))
        openFirstTile(in: app)
        try audit(app)
    }

    /// 09-04: a tile opens the scan with Close, its days left in Trash, Delete now and Restore. Delete now asks first
    /// (09-06); Restore asks nothing and goes back to Trash with one tile fewer, and the scan is in Throwaways again.
    func testOpenATrashedScanAndRestoreIt() throws {
        let app = seededApp()
        let throwaways = app.buttons[AccessibilityID.Home.collectionRow(.throwaways)]
        XCTAssertTrue(throwaways.waitForExistence(timeout: 5))
        XCTAssertEqual(throwaways.label, "Throwaways, 1")
        openTrash(in: app)
        XCTAssertTrue(waitFor(tiles(in: app), count: 5))

        openFirstTile(in: app)
        let header = app.descendants(matching: .any)[AccessibilityID.TrashViewer.header]
        XCTAssertEqual(header.label, "Trashed scan 5")
        XCTAssertEqual(header.value as? String, "26 days left")
        XCTAssertFalse(app.buttons[AccessibilityID.Viewer.details].exists)
        try audit(app)

        app.buttons[AccessibilityID.TrashViewer.deleteNow].tap()
        let deleteOne = app.alerts["Delete permanently?"]
        XCTAssertTrue(deleteOne.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteOne.staticTexts["Trashed scan 5 will be deleted. This can’t be undone."].exists)
        attachScreenshot("trash-viewer-delete-now", of: app)
        deleteOne.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.TrashViewer.restore].waitForExistence(timeout: 5))

        app.buttons[AccessibilityID.TrashViewer.restore].tap()
        XCTAssertTrue(app.staticTexts[AccessibilityID.Trash.header].waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor(tiles(in: app), count: 4))
        XCTAssertFalse(
            tiles(in: app).matching(NSPredicate(format: "label BEGINSWITH %@", "Trashed scan 5,")).firstMatch
                .exists)

        app.buttons[AccessibilityID.Grid.back].tap()
        XCTAssertTrue(throwaways.waitForExistence(timeout: 5))
        XCTAssertEqual(throwaways.label, "Throwaways, 2")
    }

    // MARK: Steps

    /// Long press: Open, Restore with where it goes, Delete now. Restore asks nothing.
    private func restoreByLongPress(in app: XCUIApplication) throws {
        tiles(in: app).firstMatch.press(forDuration: 1)
        let restore = menuItem("Restore", in: app)
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertTrue(menuItem("Open", in: app).exists)
        XCTAssertTrue(menuItem("Delete now", in: app).exists)
        attachScreenshot("trash-long-press", of: app)
        restore.tap()
        XCTAssertTrue(waitFor(tiles(in: app), count: 4))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    /// Select two, then Delete 2 asks first; deleting ends select mode.
    private func deleteTwoBySelecting(in app: XCUIApplication) throws {
        app.buttons[AccessibilityID.Trash.select].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        tiles(in: app).element(boundBy: 0).tap()
        tiles(in: app).element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["2 selected"].waitForExistence(timeout: 5))
        assertIdentifiers([AccessibilityID.Trash.deleteSelected, AccessibilityID.Trash.restoreSelected], in: app)
        XCTAssertEqual(app.buttons[AccessibilityID.Trash.deleteSelected].label, "Delete 2")
        XCTAssertEqual(app.buttons[AccessibilityID.Trash.restoreSelected].label, "Restore 2")
        try audit(app)
        app.buttons[AccessibilityID.Trash.deleteSelected].tap()
        let deleteTwo = app.alerts["Delete 2 scans permanently?"]
        XCTAssertTrue(deleteTwo.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteTwo.staticTexts["They’ll be deleted. This can’t be undone."].exists)
        attachScreenshot("trash-delete-2", of: app)
        deleteTwo.buttons["Delete"].tap()
        XCTAssertTrue(waitFor(tiles(in: app), count: 2))
        XCTAssertTrue(app.buttons[AccessibilityID.Trash.emptyTrash].waitForExistence(timeout: 5))
    }

    /// Empty Trash asks first, then the empty state shows.
    private func emptyTrash(in app: XCUIApplication) throws {
        app.buttons[AccessibilityID.Trash.emptyTrash].tap()
        let empty = app.alerts["Empty Trash?"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertTrue(empty.staticTexts["Deletes 2 scans permanently. This can’t be undone."].exists)
        attachScreenshot("trash-empty-trash", of: app)
        empty.buttons["Empty Trash"].tap()
        XCTAssertTrue(app.staticTexts["Trash is empty"].waitForExistence(timeout: 5))
        XCTAssertEqual(tiles(in: app).count, 0)
        XCTAssertFalse(app.buttons[AccessibilityID.Trash.select].exists)
        try audit(app)
    }

    /// Home's Trash row, with its count.
    private func openTrash(in app: XCUIApplication) {
        let row = app.buttons[AccessibilityID.Home.trashRow]
        XCTAssertTrue(row.label.contains("Trash") && row.label.contains("5"), row.label)
        row.tap()
        XCTAssertTrue(app.staticTexts[AccessibilityID.Trash.header].waitForExistence(timeout: 5))
    }

    /// The soonest-gone tile opens the Trash viewer.
    private func openFirstTile(in app: XCUIApplication) {
        tiles(in: app).firstMatch.tap()
        assertIdentifiers(AccessibilityID.TrashViewer.all, in: app)
    }

    private func tiles(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix))
    }

    /// A menu item by the start of its label. Restore's subtitle isn't in the tree; the screenshot shows it.
    private func menuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// Menus and alerts are never snapshotted: a screenshot is kept for review instead.
    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func waitFor(_ query: XCUIElementQuery, count: Int) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        return XCTWaiter.wait(for: [matches], timeout: 5) == .completed
    }
}
