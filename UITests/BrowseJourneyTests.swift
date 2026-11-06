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
        edgeSwipeBack(in: app)
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
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForExistence(timeout: 5))
        // One page: no strip.
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Viewer.strip].exists)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.page].exists)
    }

    func testOpenAScanFromAGridAndSwipePages() throws {
        let app = seededApp()
        openThreePageScan(in: app)
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)
        try audit(app)

        assertPageLabel("Page 1 of 3", in: app)
        app.windows.firstMatch.swipeLeft()
        assertPageLabel("Page 2 of 3", in: app)
        app.windows.firstMatch.swipeLeft()
        assertPageLabel("Page 3 of 3", in: app)
        app.windows.firstMatch.swipeRight()
        assertPageLabel("Page 2 of 3", in: app)

        // Leaving and coming back to the app evaluates the root again; the viewer stays on its page.
        XCUIDevice.shared.press(.home)
        app.activate()
        assertPageLabel("Page 2 of 3", in: app)

        app.buttons[AccessibilityID.Viewer.back].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
    }

    func testViewerAuditAtLargestText() throws {
        let app = seededApp(largestText: true)
        openThreePageScan(in: app)
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)
        try audit(app)
    }

    func testEdgeSwipeGoesBackFromTheViewer() {
        let app = seededApp()
        openThreePageScan(in: app)
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
    }

    func testEdgeSwipeGoesBackFromALaterPage() {
        let app = seededApp()
        openThreePageScan(in: app)
        app.windows.firstMatch.swipeLeft()
        assertPageLabel("Page 2 of 3", in: app)
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
    }

    func testEdgeSwipeGoesBackFromAZoomedPage() {
        let app = seededApp()
        openThreePageScan(in: app)
        app.descendants(matching: .any)[AccessibilityID.Viewer.page].firstMatch.doubleTap()
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
    }

    private func openReceipts(in app: XCUIApplication) {
        open(.receipts, in: app)
    }

    private func open(_ collection: BuiltInCollection, in app: XCUIApplication) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(collection)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
    }

    /// The seed's Documents scans have three pages.
    private func openThreePageScan(in app: XCUIApplication) {
        open(.documents, in: app)
        tiles(in: app).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].waitForExistence(timeout: 5))
    }

    private func assertPageLabel(_ label: String, in app: XCUIApplication, line: UInt = #line) {
        let strip = app.descendants(matching: .any)[AccessibilityID.Viewer.strip]
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: strip)
        XCTAssertEqual(XCTWaiter.wait(for: [matches], timeout: 5), .completed, label, line: line)
    }

    private func edgeSwipeBack(in app: XCUIApplication) {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )
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
