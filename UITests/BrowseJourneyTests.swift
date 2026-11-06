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
            XCTAssertTrue(
                app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5), row)
            app.buttons[AccessibilityID.Grid.back].tap()
            XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 5), row)
        }
    }

    func testOpenReceiptsThenScanPreselectsReceipts() throws {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12", "-FakeCamera", "1", "-FakeReader"])
        openReceipts(in: app)
        assertIdentifiers(AccessibilityID.Grid.all, in: app)
        XCTAssertGreaterThan(tiles(in: app).count, 0)
        try audit(app)

        let scan = app.buttons[AccessibilityID.Grid.scan]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: scan)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        scan.tap()
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        let save = app.buttons[AccessibilityID.Review.save]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        let collection = app.descendants(matching: .any)[AccessibilityID.Review.collection]
        XCTAssertTrue(collection.waitForExistence(timeout: 5))
        XCTAssertEqual(collection.label, "Collection")
        XCTAssertEqual(collection.value as? String, "Receipts")
        let saveEnabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [saveEnabled], timeout: 5), .completed)
    }

    func testGridAuditAtLargestText() throws {
        let app = seededApp(largestText: true)
        openReceipts(in: app)
        XCTAssertGreaterThan(tiles(in: app).count, 0)
        try audit(app)
    }

    func testEdgeSwipeGoesBackFromTheGrid() {
        let app = seededApp()
        openReceipts(in: app)
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 5))
    }

    func testTileOpensAScan() {
        let app = seededApp()
        openReceipts(in: app)
        tiles(in: app).firstMatch.tap()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.descendants(matching: .any)[AccessibilityID.Grid.header])
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
    }

    private func openReceipts(in app: XCUIApplication) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
    }

    private func tiles(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
    }

    func testHomeWithScansAuditAtLargestText() throws {
        let app = seededApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.allRow].waitForExistence(timeout: 5))
        try audit(app)
    }
}
