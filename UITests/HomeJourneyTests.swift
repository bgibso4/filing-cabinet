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

    /// Home and Settings fit the screen, so a bounce shows no scroll bar there; a grid that scrolls keeps its own
    /// (phone check F4). The scroll bar is in the tree only while it shows, so each is bounced first.
    func testOnlyScreensThatScrollShowAScrollBar() {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"])
        let receipts = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        waitForSeeding(of: receipts, count: 3)
        let scrollBars = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Vertical scroll bar"))

        receipts.drag(by: -300)
        XCTAssertEqual(scrollBars.count, 0, "Home showed a scroll bar")

        app.buttons[AccessibilityID.Home.settings].tap()
        let collections = app.buttons[AccessibilityID.Settings.collections]
        XCTAssertTrue(collections.appears(within: 5))
        collections.drag(by: 300)
        XCTAssertEqual(scrollBars.count, 0, "Settings showed a scroll bar")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons[AccessibilityID.Home.allRow].tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        tile.drag(by: -300)
        XCTAssertGreaterThan(scrollBars.count, 0, "All Scans showed no scroll bar")
    }

    /// Home rests large under the gear and collapses on scroll, like Passwords' root (B9, M11): the system bar's own
    /// title, large at rest and small once collapsed (plan 3, E9).
    func testTitleCollapsesOnScroll() {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"])
        let receipts = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        waitForSeeding(of: receipts, count: 3)
        XCTAssertTrue(app.header("Filing Cabinet", shows: .large, within: 5))

        receipts.drag(by: -300)
        XCTAssertTrue(app.header("Filing Cabinet", shows: .small, within: 5))

        app.buttons[AccessibilityID.Home.collectionRow(.wallet)].drag(by: 300)
        XCTAssertTrue(app.header("Filing Cabinet", shows: .large, within: 5))

        let gear = app.buttons[AccessibilityID.Home.settings]
        XCTAssertEqual(gear.label, "Settings")
        gear.tap()
        XCTAssertTrue(app.header("Settings").appears(within: 5))
    }

    func testAuditAtLargestTextOfHome() throws {
        let app = launchApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].isHittable)
        // Settled before the audit: Home at rest with its title large, and the row the Scan bar cuts (Receipts at this
        // size) resolvable. On a slow CI runner the audit otherwise reported that row with no element, so the cut-row
        // exemption couldn't match it.
        XCTAssertTrue(app.header("Filing Cabinet", shows: .large, within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.collectionRow(.receipts)].appears(within: 5))
        try audit(app)
    }
}
