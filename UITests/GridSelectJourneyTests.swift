import Core
import XCTest

/// Select on a collection grid (#68), as in Trash: tick scans, then Move to Trash in Scan's place.
@MainActor
final class GridSelectJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Twelve seeded scans, Receipts open: three receipts.
    private func receiptsApp() -> XCUIApplication {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"])
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        waitForSeeding(of: row, count: 3)
        row.tap()
        XCTAssertTrue(app.header(.receipts).appears(within: 5))
        return app
    }

    /// #68: Select on a grid ticks scans, says how many in the subtitle, and puts Move to Trash in Scan's place, off
    /// until something is ticked. Move to Trash asks first, as the viewer's does (06-04), then moves the ticked scans
    /// and ends select mode.
    func testSelectTwoAndMoveThemToTrash() throws {
        let app = receiptsApp()
        XCTAssertTrue(tiles(in: app).satisfies("count == %d", 3, within: 5))
        let select = app.buttons[AccessibilityID.Grid.select]
        select.tap()
        XCTAssertTrue(app.staticTexts["0 selected"].appears(within: 5))
        XCTAssertEqual(select.label, "Cancel")
        let move = app.buttons[AccessibilityID.Grid.moveToTrash]
        XCTAssertTrue(move.exists)
        XCTAssertFalse(move.isEnabled)
        XCTAssertFalse(app.buttons[AccessibilityID.Grid.scan].exists, "Scan stayed in select mode")

        tiles(in: app).element(boundBy: 0).tap()
        tiles(in: app).element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["2 selected"].appears(within: 5))
        XCTAssertTrue(tiles(in: app).element(boundBy: 0).isSelected)
        XCTAssertEqual(move.label, "Move 2 to Trash")
        // Not audited in select mode: the audit reports the bar's glass Cancel pill as low contrast with no element
        // (FC Speed iPhone 17, 2026-11-09; Select passes). Trash's exemptions cover the same pill there only, and
        // widening them needs Ben's OK. The grid with Select is audited in BrowseJourneyTests.

        move.tap()
        let message = app.staticTexts["These 2 receipts move to Trash. You can restore them for 30 days."]
        XCTAssertTrue(message.appears(within: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "grid-move-2-to-trash"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Grid.moveToTrash)
        ).firstMatch.tap()

        XCTAssertTrue(tiles(in: app).satisfies("count == %d", 1, within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.scan].appears(within: 5))
        XCTAssertEqual(select.label, "Select")
        XCTAssertFalse(move.exists)
    }

    private func tiles(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
    }
}
