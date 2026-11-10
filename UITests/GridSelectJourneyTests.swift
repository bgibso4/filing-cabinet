import Core
import ScreenModels
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
        // Not audited at this size: the audit reads the last ticked tile's "2 months left" as "contrast nearly
        // passed", every run, though the same caption passes everywhere else (#79). testAuditOfSelectModeAtLargestText
        // audits select mode meanwhile.

        move.tap()
        let message = app.staticTexts["These 2 receipts move to Trash. You can restore them for 30 days."]
        XCTAssertTrue(message.appears(within: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "grid-move-2-to-trash"
        shot.lifetime = .keepAlways
        add(shot)
        confirmMove(in: app)

        XCTAssertTrue(tiles(in: app).satisfies("count == %d", 1, within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.scan].appears(within: 5))
        XCTAssertEqual(select.label, "Select")
        XCTAssertFalse(move.exists)

        // Select again: the confirmation the move answered doesn't come back by itself (review M2).
        select.tap()
        XCTAssertTrue(app.staticTexts["0 selected"].appears(within: 5))
        XCTAssertFalse(
            app.staticTexts["This receipt moves to Trash. You can restore it for 30 days."].appears(within: 1))
        XCTAssertFalse(message.exists)
    }

    /// Select mode at the largest text size: the subtitle, the ticks and Move to Trash in Scan's place.
    func testAuditOfSelectModeAtLargestText() throws {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"], largestText: true)
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        waitForSeeding(of: row, count: 3)
        row.tap()
        let select = app.buttons[AccessibilityID.Grid.select]
        XCTAssertTrue(select.appears(within: 5))
        select.tap()
        tiles(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.moveToTrash].isEnabled)
        try audit(app)
    }

    /// The grid emptied by its own selection (its only card moved to Trash) comes out with the large title, the
    /// system's gap under the back button, and Select greyed out, as an empty grid opened from Home (review I3).
    func testMovingTheLastScanShowsTheEmptyGridLarge() {
        // Scan 1 is the seed's only wallet card.
        let app = launchApp(["-SeedScans", "1", "-FixedDate", "2026-10-12"])
        let row = app.buttons[AccessibilityID.Home.collectionRow(.wallet)]
        waitForSeeding(of: row, count: 1)
        row.tap()
        XCTAssertTrue(app.header(.wallet, shows: .small, within: 5), "The grid didn't rest small")
        let select = app.buttons[AccessibilityID.Grid.select]
        select.tap()
        tiles(in: app).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].appears(within: 5))
        app.buttons[AccessibilityID.Grid.moveToTrash].tap()
        XCTAssertTrue(app.staticTexts["This card moves to Trash. You can restore it for 30 days."].appears(within: 5))
        confirmMove(in: app)

        XCTAssertTrue(app.staticTexts["No cards yet"].appears(within: 5))
        XCTAssertTrue(app.header(.wallet, shows: .large, within: 5), "The large title isn't showing")
        XCTAssertFalse(app.header(.wallet, shows: .small, within: 1), "The bar collapsed")
        XCTAssertEqual(
            app.largeTitleGap(CollectionText.name(.wallet)),
            largeTitleGap,
            accuracy: largeTitleGapTolerance,
            "The large title isn't the system's gap under the back button")
        XCTAssertEqual(select.label, "Select")
        XCTAssertFalse(select.isEnabled)
    }

    /// The confirmation's Move to Trash, beside the bar's button of the same name.
    private func confirmMove(in app: XCUIApplication) {
        app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Grid.moveToTrash)
        ).firstMatch.tap()
    }

    private func tiles(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
    }
}
