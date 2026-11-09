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
            XCTAssertTrue(row.appears(within: 5), collection)
        }
        let scan = app.buttons["home.scan"]
        XCTAssertTrue(scan.appears(within: 5))
        XCTAssertTrue(scan.isHittable)
        XCTAssertEqual(scan.label, "Scan")
        assertIdentifiers([AccessibilityID.Home.scan], in: app)
        try audit(app)
    }

    /// Home rests large under the gear and collapses on scroll, like Passwords' root (B9, M11). The small bar title is
    /// the header in both states (M6, amended): hidden under the large title at rest, hittable once collapsed.
    func testTitleCollapsesOnScroll() {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"])
        let receipts = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        waitForSeeding(of: receipts, count: 3)
        let header = app.staticTexts[AccessibilityID.Home.header]
        XCTAssertTrue(header.appears(within: 5))
        XCTAssertTrue(header.satisfies("isHittable == false", within: 5))

        receipts.drag(by: -300)
        XCTAssertTrue(header.satisfies("isHittable == true", within: 5))

        app.buttons[AccessibilityID.Home.collectionRow(.wallet)].drag(by: 300)
        XCTAssertTrue(header.satisfies("isHittable == false", within: 5))

        let gear = app.buttons[AccessibilityID.Home.settings]
        XCTAssertEqual(gear.label, "Settings")
        gear.tap()
        XCTAssertTrue(app.staticTexts[AccessibilityID.Settings.header].appears(within: 5))
    }

    func testAuditAtLargestTextOfHome() throws {
        let app = launchApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].isHittable)
        try audit(app)
    }
}
