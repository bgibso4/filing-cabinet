import Core
import XCTest

@MainActor
final class BrowseJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func seededApp(largestText: Bool = false) -> XCUIApplication {
        launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"], largestText: largestText)
    }

    func testHomeRowsOpenTheirDestinations() throws {
        let app = seededApp()
        // Recent and All Scans appear once the seeded scans are in.
        assertIdentifiers(AccessibilityID.Home.all, in: app)
        try audit(app)

        let rows =
            BuiltInCollection.allCases.map(AccessibilityID.Home.collectionRow)
            + [AccessibilityID.Home.recentRow, AccessibilityID.Home.allRow]
        for row in rows {
            let button = app.buttons[row]
            XCTAssertTrue(button.waitForExistence(timeout: 5), row)
            button.tap()
            // Until Task 16 the destination is a placeholder carrying the grid header's identifier.
            XCTAssertTrue(
                app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5), row)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 5), row)
        }
    }

    func testHomeWithScansAuditAtLargestText() throws {
        let app = seededApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.allRow].waitForExistence(timeout: 5))
        try audit(app)
    }
}
