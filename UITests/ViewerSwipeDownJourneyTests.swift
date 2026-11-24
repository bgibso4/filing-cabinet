import Core
import XCTest

/// A swipe down on a scan's page closes it, back into the thumbnail it opened from, like Photos (#98): from a grid,
/// Trash and Search. With Details up it closes only Details, and a zoomed page pans instead. With `-Animations`: the
/// system's swipe down never finishes with animations off.
@MainActor
final class ViewerSwipeDownJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Twelve scans dated 0 to 11 days ago; scan 1, in Documents, has three pages.
    private func seededApp() -> XCUIApplication {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12", "-Animations"])
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 3)
        return app
    }

    func testASwipeDownClosesTheScanFromALaterPage() {
        let app = seededApp()
        openThreePageScan(in: app)
        app.windows.firstMatch.swipeLeft()
        let strip = app.descendants(matching: .any)[AccessibilityID.Viewer.strip]
        XCTAssertTrue(strip.satisfies("label == %@", "Page 2 of 3", within: 5))

        swipeDownOnThePage(in: app)
        XCTAssertTrue(viewerHeader(in: app).disappears(within: 5), "A swipe down left the scan open")
        XCTAssertTrue(app.header(.documents).appears(within: 5))
    }

    /// With Details up, the first swipe down closes Details only (#71); the second closes the scan.
    func testASwipeDownWithDetailsUpClosesDetailsFirst() {
        let app = seededApp()
        openThreePageScan(in: app)
        app.buttons[AccessibilityID.Viewer.details].tap()
        let sheet = app.descendants(matching: .any)[AccessibilityID.Details.sheet]
        XCTAssertTrue(sheet.appears(within: 5))
        XCTAssertTrue(viewerHeader(in: app).disappears(within: 5), "Details never finished opening")

        swipeDownOnThePage(in: app)
        XCTAssertTrue(sheet.disappears(within: 5))
        XCTAssertTrue(viewerHeader(in: app).satisfies("hittable == true", within: 5), "The scan closed with Details")

        swipeDownOnThePage(in: app)
        XCTAssertTrue(app.header(.documents).appears(within: 5))
    }

    func testASwipeDownOnAZoomedPageKeepsTheScan() {
        let app = seededApp()
        openThreePageScan(in: app)
        let page = app.descendants(matching: .any)[AccessibilityID.Viewer.page].firstMatch
        page.doubleTap()
        XCTAssertTrue(page.satisfies("value == %@", "Zoomed", within: 5), "The page never reported being zoomed")

        swipeDownOnThePage(in: app)
        XCTAssertTrue(page.exists, "A drag on a zoomed page closed the scan")
        XCTAssertEqual(page.value as? String, "Zoomed")
    }

    func testASwipeDownClosesATrashedScan() {
        let app = launchApp(["-SeedScans", "6", "-SeedTrash", "5", "-FixedDate", "2026-10-12", "-Animations"])
        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        XCTAssertTrue(trashRow.satisfies("label CONTAINS %@", "5", within: seedingTimeout), trashRow.label)
        trashRow.tap()
        XCTAssertTrue(app.header("Trash").appears(within: 5))
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix)
        )
        .firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        tile.tap()
        let header = app.descendants(matching: .any)[AccessibilityID.TrashViewer.header]
        XCTAssertTrue(header.appears(within: 5))

        swipeDownOnThePage(in: app)
        XCTAssertTrue(header.disappears(within: 5), "A swipe down left the trashed scan open")
        XCTAssertTrue(app.header("Trash").appears(within: 5))
    }

    /// Search has its own navigation stack, so its own match between result and viewer.
    func testASwipeDownClosesASearchResult() {
        let app = seededApp()
        openSearch(in: app).typeText("scan 4")
        let result = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Search.resultPrefix)
        )
        .firstMatch
        XCTAssertTrue(result.appears(within: 5))
        result.tap()
        XCTAssertTrue(viewerHeader(in: app).appears(within: 5))

        swipeDownOnThePage(in: app)
        XCTAssertTrue(result.appears(within: 5), "A swipe down didn't return to the results")
        // Every test ends on Home, so the next one's relaunch never has to take a presented cover down.
        app.buttons[AccessibilityID.Search.close].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.search].appears(within: 5))
    }

    private func viewerHeader(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Viewer.header]
    }

    private func openThreePageScan(in app: XCUIApplication) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(.documents)]
        XCTAssertTrue(row.appears(within: 5))
        row.tap()
        XCTAssertTrue(app.header(.documents).appears(within: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
            .firstMatch.tap()
        XCTAssertTrue(viewerHeader(in: app).appears(within: 5))
    }

    /// From a little below the header, a third of the screen down: far enough to close, the way a thumb swipes.
    private func swipeDownOnThePage(in app: XCUIApplication) {
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 300)))
    }
}
