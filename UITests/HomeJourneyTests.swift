import Core
import XCTest

@MainActor
final class HomeJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testHomeShowsCollectionsAndScan() throws {
        let app = launchApp()
        // Literal identifiers on purpose: a drifted scheme in AccessibilityID must fail here.
        for collection in ["wallet", "receipts", "notes", "documents", "throwaways"] {
            let row = app.descendants(matching: .any)["home.collection.\(collection)"]
            XCTAssertTrue(row.waitForExistence(timeout: 5), collection)
        }
        let scan = app.buttons["home.scan"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        XCTAssertTrue(scan.isHittable)
        XCTAssertEqual(scan.label, "Scan")
        assertIdentifiers([AccessibilityID.Home.scan], in: app)
        try audit(app)
    }

    func testHomeAuditAtLargestText() throws {
        let app = launchApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].isHittable)
        try audit(app)
    }
}
