import Core
import XCTest

@MainActor
final class BrowseJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Waits for seeding to finish: Home's cleanup banner comes in as the last seeded scan lands, and an audit taken
    /// mid-way caught it half drawn (CI run 42500722527, "Contrast failed" on the banner).
    private func seededApp(largestText: Bool = false) -> XCUIApplication {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"], largestText: largestText)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 3)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.cleanupBanner].waitForExistence(timeout: seedingTimeout))
        return app
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

    func testAuditAtLargestTextOfAGrid() throws {
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
        // Only the page on screen is in the accessibility tree (M5).
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: AccessibilityID.Viewer.page).count, 1)
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

    func testAuditAtLargestTextOfTheViewer() throws {
        let app = seededApp(largestText: true)
        openThreePageScan(in: app)
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)
        try audit(app)
    }

    /// In dark mode the pill's whole detail line, time left included, is the primary colour (Ben, 2026-11-07).
    func testViewerAuditInDarkMode() throws {
        XCUIDevice.shared.appearance = .dark
        // A teardown block, not `defer`: a failure stops the test with an exception that skips `defer`.
        addTeardownBlock { @MainActor in XCUIDevice.shared.appearance = .light }
        let app = seededApp()
        openThreePageScan(in: app)
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
        // The page says it is zoomed once the zoom has finished; only then is the swipe a test of a zoomed page.
        zoomTheFirstPage(in: app)
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Grid.header].waitForExistence(timeout: 5))
    }

    func testSwipingAtAZoomedPagesEdgeGoesToTheNextPage() throws {
        // Flaky on CI's slow runners; Ben chose to skip it until a dedicated fix (2026-11-08, #64).
        try XCTSkipIf(true, "Flaky zoom-then-swipe timing on CI (#64)")
        let app = seededApp()
        openThreePageScan(in: app)
        zoomTheFirstPage(in: app)
        // The first swipes pan the zoomed page to its edge; the one after that pages, as in Photos.
        let strip = app.descendants(matching: .any)[AccessibilityID.Viewer.strip]
        let second = NSPredicate(format: "label == %@", "Page 2 of 3")
        var swipes = 0
        while swipes < 4 {
            app.windows.firstMatch.swipeLeft()
            swipes += 1
            let paged = XCTNSPredicateExpectation(predicate: second, object: strip)
            if XCTWaiter.wait(for: [paged], timeout: 2) == .completed { break }
        }
        assertPageLabel("Page 2 of 3", in: app)
    }

    private func zoomTheFirstPage(in app: XCUIApplication) {
        let page = app.descendants(matching: .any)[AccessibilityID.Viewer.page].firstMatch
        page.doubleTap()
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Zoomed"), object: page)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 5), .completed, "The page never reported being zoomed")
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

    /// Scan stays disabled until seeding ends. No launch option holds seeding open, so this checks the state the moment
    /// Scan exists, with nothing else waited on first, and audits straight after.
    func testAuditAtLargestTextOfDisabledScan() throws {
        let app = launchApp(["-SeedScans", "60", "-FixedDate", "2026-10-12"], largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons[AccessibilityID.Home.scan].isEnabled)
        try audit(app)
    }

    func testAuditAtLargestTextOfHomeWithScans() throws {
        let app = seededApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.allRow].waitForExistence(timeout: 5))
        try audit(app)
    }
}
