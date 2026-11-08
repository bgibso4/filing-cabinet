import Core
import XCTest

// MARK: Edit, Trash and restore

/// The steps of `testScanEditTrashRestore`, one screen each. Kept out of `ScanJourneyTests.swift` for its length.
extension ScanJourneyTests {
    /// From Home, the collection's only scan, checked by its tile label, opens in the viewer.
    func openOnlyTile(
        of collection: BuiltInCollection, in app: XCUIApplication, label: String? = nil, line: UInt = #line
    ) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(collection)]
        let counted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS '1'"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [counted], timeout: 5), .completed, row.label, line: line)
        row.tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5), line: line)
        if let label { XCTAssertEqual(tile.label, label, line: line) }
        tile.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForExistence(timeout: 5), line: line)
    }

    /// The header pill opens Details; the new title is typed over the old one and the sheet closes.
    func renameInDetails(to title: String, in app: XCUIApplication) {
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        header.tap()
        let rename = app.buttons[AccessibilityID.Details.title]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.tap()
        let field = app.textFields[AccessibilityID.Details.titleField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.buttons[AccessibilityID.Details.clearTitle].tap()
        field.typeText("\(title)\n")
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        XCTAssertEqual(rename.label, "Rename \(title)")
        app.swipeDownOnSheet()
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertEqual(header.label, "\(title), details")
    }

    /// The viewer's Trash asks first, then pops back to the empty grid; Home's Trash row counts the scan.
    func moveToTrashFromTheViewer(in app: XCUIApplication) {
        app.buttons[AccessibilityID.Viewer.trash].tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Viewer.trash)
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForNonExistence(timeout: 5))
        let back = app.buttons[AccessibilityID.Grid.back]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }

    /// Home's Trash row opens Trash; the scan has its full 30 days (M8), and its viewer's Restore empties Trash.
    func restoreFromTrash(_ title: String, in app: XCUIApplication) {
        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        let counted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", "Trash, 1"), object: trashRow)
        XCTAssertEqual(XCTWaiter.wait(for: [counted], timeout: 5), .completed, trashRow.label)
        trashRow.tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        XCTAssertEqual(tile.label, "\(title), Receipts, 30 days left")
        tile.tap()
        let restore = app.buttons[AccessibilityID.TrashViewer.restore]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.staticTexts["Trash is empty"].waitForExistence(timeout: 5))
        app.buttons[AccessibilityID.Grid.back].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 5))
    }
}
