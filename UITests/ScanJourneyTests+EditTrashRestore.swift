import Core
import XCTest

// MARK: Edit, Trash and restore

/// The steps of `testScanEditTrashRestore`, one screen each. Kept out of `ScanJourneyTests.swift` for its length.
extension ScanJourneyTests {
    /// How long Apple's rating prompt may take to show: twice the 9.7 s it took on CI (run 43554564482).
    private static let ratingPromptTimeout: TimeInterval = 20

    /// Apple's rating prompt: Not Now, and waits for it to go. A development build always shows the prompt when asked
    /// (Apple's `requestReview` documentation), so it must come. It is Apple's service that shows it, and on a CI
    /// simulator that took 9.7 s after Home came back (run 43554564482), against about 1 s on a Mac. The earlier
    /// 5 s wait read that as "Apple chose not to show it", returned, and the prompt then covered Home.
    func dismissRatingPrompt(in app: XCUIApplication) {
        let notNow = app.buttons["Not Now"]
        XCTAssertTrue(notNow.appears(within: Self.ratingPromptTimeout), "Apple's rating prompt never showed")
        // The prompt scales down into place and ignores taps until it has; a tap while it still read 1.004× its
        // resting size was dropped and the prompt stayed (2026-11-13). Tap once its frame holds still.
        XCTAssertTrue(notNow.holdsStill(within: 5), "the rating prompt never settled")
        notNow.tap()
        XCTAssertTrue(notNow.disappears(within: 5))
    }

    /// From Home, the collection's only scan, opens in the viewer. `label` checks the tile's label: its start and its
    /// end, because the middle is the scan's day, which is the real one in this journey.
    func openOnlyTile(
        of collection: BuiltInCollection,
        in app: XCUIApplication,
        label: (start: String, end: String)? = nil,
        line: UInt = #line
    ) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(collection)]
        XCTAssertTrue(row.satisfies("exists == true AND label CONTAINS '1'", within: 5), row.label, line: line)
        row.tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.appears(within: 5), line: line)
        if let label {
            XCTAssertTrue(tile.label.hasPrefix(label.start) && tile.label.hasSuffix(label.end), tile.label, line: line)
        }
        tile.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5), line: line)
    }

    /// The header pill opens Details; the new title is typed over the old one and the sheet closes.
    func renameInDetails(to title: String, in app: XCUIApplication) {
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        header.tap()
        let rename = app.buttons[AccessibilityID.Details.title]
        XCTAssertTrue(rename.appears(within: 5))
        rename.tap()
        let field = app.textFields[AccessibilityID.Details.titleField]
        XCTAssertTrue(field.appears(within: 5))
        app.buttons[AccessibilityID.Details.clearTitle].tap()
        field.typeText("\(title)\n")
        XCTAssertTrue(rename.appears(within: 5))
        XCTAssertEqual(rename.label, "Rename \(title)")
        app.swipeDownOnSheet()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.sheet].disappears(within: 5))
        XCTAssertTrue(header.appears(within: 5))
        XCTAssertEqual(header.label, "\(title), details")
    }

    /// The viewer's Trash asks first, then pops back to the empty grid; Home's Trash row counts the scan.
    func moveToTrashFromTheViewer(in app: XCUIApplication) {
        app.buttons[AccessibilityID.Viewer.trash].tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Viewer.trash)
        ).firstMatch
        XCTAssertTrue(confirm.appears(within: 5))
        confirm.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityID.Viewer.header].disappears(within: 5))
        let back = app.buttons[AccessibilityID.Grid.back]
        XCTAssertTrue(back.appears(within: 5))
        back.tap()
    }

    /// Home's Trash row opens Trash; the scan has its full 30 days (M8), and its viewer's Restore empties Trash.
    func restoreFromTrash(_ title: String, in app: XCUIApplication) {
        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        XCTAssertTrue(trashRow.satisfies("exists == true AND label == %@", "Trash, 1", within: 5), trashRow.label)
        trashRow.tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        XCTAssertEqual(tile.label, "\(title), Receipts, 30 days left")
        tile.tap()
        let restore = app.buttons[AccessibilityID.TrashViewer.restore]
        XCTAssertTrue(restore.appears(within: 5))
        restore.tap()
        XCTAssertTrue(app.staticTexts["Trash is empty"].appears(within: 5))
        let back = app.buttons[AccessibilityID.Grid.back]
        XCTAssertTrue(back.appears(within: 5))
        back.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 5))
    }
}
