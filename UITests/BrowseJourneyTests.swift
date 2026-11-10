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
        XCTAssertTrue(app.buttons[AccessibilityID.Home.cleanupBanner].appears(within: seedingTimeout))
        return app
    }

    func testHomeRowsOpenTheirDestinations() throws {
        let app = seededApp()
        // Recent and All Scans appear once the seeded scans are in.
        assertIdentifiers(AccessibilityID.Home.all, in: app)
        try audit(app)

        let rows =
            BuiltInCollection.allCases.map { (AccessibilityID.Home.collectionRow($0), app.header($0)) }
            + [
                (AccessibilityID.Home.recentRow, app.header("Recent")),
                (AccessibilityID.Home.allRow, app.header("All Scans")),
            ]
        for (row, header) in rows {
            let button = app.buttons[row]
            XCTAssertTrue(button.appears(within: 5), row)
            button.tap()
            XCTAssertTrue(header.appears(within: 5), row)
            app.buttons[AccessibilityID.Grid.back].tap()
            XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 5), row)
        }
    }

    func testOpenReceiptsThenScanPreselectsReceipts() throws {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12", "-FakeCamera", "1", "-FakeReader"])
        openReceipts(in: app)
        assertIdentifiers(AccessibilityID.Grid.all, in: app)
        XCTAssertGreaterThan(tiles(in: app).count, 0)
        try audit(app)

        let scan = app.buttons[AccessibilityID.Grid.scan]
        XCTAssertTrue(scan.satisfies("isEnabled == true", within: 5))
        scan.tap()
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.appears(within: 5))
        finish.tap()

        let save = app.buttons[AccessibilityID.Review.save]
        XCTAssertTrue(save.appears(within: 5))
        let collection = app.descendants(matching: .any)[AccessibilityID.Review.collection]
        XCTAssertTrue(collection.appears(within: 5))
        XCTAssertEqual(collection.label, "Collection")
        XCTAssertEqual(collection.value as? String, "Receipts")
        XCTAssertTrue(save.satisfies("isEnabled == true", within: 5))
    }

    func testAuditAtLargestTextOfAGrid() throws {
        let app = seededApp(largestText: true)
        openReceipts(in: app)
        XCTAssertGreaterThan(tiles(in: app).count, 0)
        try audit(app)
    }

    /// An empty collection rests with the large title showing and doesn't scroll (B5).
    func testEmptyGridDoesNotScroll() {
        let app = launchApp()
        openReceipts(in: app)
        assertEmptyReceiptsHoldStill(in: app)
    }

    /// A grid that empties while it is open (its only scan moved to Trash from the viewer, which pops back to it) comes
    /// back with the large title showing, and holds still, as one opened empty does (B5).
    func testAGridEmptiedFromTheViewerShowsTheLargeTitle() {
        // Scan 2 is the seed's only receipt.
        let app = launchApp(["-SeedScans", "2", "-FixedDate", "2026-10-12"])
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 1)
        openReceipts(in: app)
        XCTAssertTrue(app.header(.receipts, shows: .small, within: 5), "The grid didn't rest small")
        tiles(in: app).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))

        app.buttons[AccessibilityID.Viewer.trash].tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Viewer.trash)
        ).firstMatch
        XCTAssertTrue(confirm.appears(within: 5))
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].disappears(within: 5))

        assertEmptyReceiptsHoldStill(in: app)
    }

    /// The state an empty collection opened after one with scans must end in: the bar taller than the full collection's
    /// collapsed one and the large title showing. Not F6's regression test: on the phone the push's animation
    /// collapsed the bar and neither title showed, but `-UITest` turns animations off, so this journey can't catch that
    /// collapse (`HeaderSettlingTests` does).
    func testAnEmptyCollectionAfterAFullOneEndsWithTheBarExpanded() {
        // Scan 1 is the seed's only wallet card, scan 2 its only receipt: Notes is empty.
        let app = launchApp(["-SeedScans", "2", "-FixedDate", "2026-10-12"])
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 1)
        open(.wallet, in: app)
        XCTAssertTrue(app.header(.wallet, shows: .small, within: 5), "The full grid didn't rest small")
        let collapsedBar = app.navigationBars.firstMatch.frame.height
        app.buttons[AccessibilityID.Grid.back].tap()

        open(.notes, in: app)
        XCTAssertTrue(app.staticTexts["No notes yet"].appears(within: 5))
        XCTAssertTrue(app.header(.notes, shows: .large, within: 5), "The large title isn't showing")
        XCTAssertGreaterThan(app.navigationBars.firstMatch.frame.height, collapsedBar, "The bar is collapsed")
    }

    /// The large title shows, and stays; drags either way move neither it nor the empty state.
    private func assertEmptyReceiptsHoldStill(in app: XCUIApplication, line: UInt = #line) {
        let title = app.headerTitle(.receipts)
        let empty = app.staticTexts["No receipts yet"]
        XCTAssertTrue(empty.appears(within: 5), line: line)
        XCTAssertTrue(app.header(.receipts, shows: .large, within: 5), "The large title isn't showing", line: line)
        // Still large once the bar has had time to settle.
        XCTAssertFalse(app.header(.receipts, shows: .small, within: 1), "The bar collapsed", line: line)
        let frames = (title: title.frame, empty: empty.frame)

        for distance in [-300.0, 300.0] {
            empty.drag(by: distance)
            XCTAssertEqual(title.frame, frames.title, "The title moved after a \(distance) pt drag", line: line)
            XCTAssertEqual(empty.frame, frames.empty, "The empty state moved after a \(distance) pt drag", line: line)
            let large = app.header(.receipts, shows: .large, within: 0)
            XCTAssertTrue(large, "The bar collapsed after a \(distance) pt drag", line: line)
        }
    }

    func testEdgeSwipeGoesBackFromTheGrid() {
        let app = seededApp()
        openReceipts(in: app)
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 5))
    }

    func testTileOpensAScan() {
        let app = seededApp()
        openReceipts(in: app)
        tiles(in: app).firstMatch.tap()
        XCTAssertTrue(app.header(.receipts).disappears(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
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
        // `activate()` returns while iOS still scales the window up from its icon: the app is already
        // running in the foreground and Back already hittable, but Back's frame is where the scaled window put
        // it, so a tap then lands below the button once the window settles. Wait for the window's resting frame.
        let window = app.windows.firstMatch
        let restingFrame = NSValue(cgRect: window.frame)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(window.satisfies("frame == %@", restingFrame, within: 5), "The window never settled")
        assertPageLabel("Page 2 of 3", in: app)

        app.buttons[AccessibilityID.Viewer.back].tap()
        XCTAssertTrue(app.header(.documents).appears(within: 5))
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
        XCTAssertTrue(app.header(.documents).appears(within: 5))
    }

    func testEdgeSwipeGoesBackFromALaterPage() {
        let app = seededApp()
        openThreePageScan(in: app)
        app.windows.firstMatch.swipeLeft()
        assertPageLabel("Page 2 of 3", in: app)
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.header(.documents).appears(within: 5))
    }

    func testEdgeSwipeGoesBackFromAZoomedPage() {
        let app = seededApp()
        openThreePageScan(in: app)
        // The page says it is zoomed once the zoom has finished; only then is the swipe a test of a zoomed page.
        zoomTheFirstPage(in: app)
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.header(.documents).appears(within: 5))
    }

    func testSwipingAtAZoomedPagesEdgeGoesToTheNextPage() throws {
        // Flaky on CI's slow runners; Ben chose to skip it until a dedicated fix (2026-11-08, #64).
        try XCTSkipIf(true, "Flaky zoom-then-swipe timing on CI (#64)")
        let app = seededApp()
        openThreePageScan(in: app)
        zoomTheFirstPage(in: app)
        // The first swipes pan the zoomed page to its edge; the one after that pages, as in Photos.
        let strip = app.descendants(matching: .any)[AccessibilityID.Viewer.strip]
        var swipes = 0
        while swipes < 4 {
            app.windows.firstMatch.swipeLeft()
            swipes += 1
            if strip.satisfies("label == %@", "Page 2 of 3", within: 2) { break }
        }
        assertPageLabel("Page 2 of 3", in: app)
    }

    private func zoomTheFirstPage(in app: XCUIApplication) {
        let page = app.descendants(matching: .any)[AccessibilityID.Viewer.page].firstMatch
        page.doubleTap()
        XCTAssertTrue(page.satisfies("value == %@", "Zoomed", within: 5), "The page never reported being zoomed")
    }

    private func openReceipts(in app: XCUIApplication) {
        open(.receipts, in: app)
    }

    private func open(_ collection: BuiltInCollection, in app: XCUIApplication) {
        let row = app.buttons[AccessibilityID.Home.collectionRow(collection)]
        XCTAssertTrue(row.appears(within: 5))
        row.tap()
        XCTAssertTrue(app.header(collection).appears(within: 5))
    }

    /// The seed's Documents scans have three pages.
    private func openThreePageScan(in app: XCUIApplication) {
        open(.documents, in: app)
        tiles(in: app).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
    }

    private func assertPageLabel(_ label: String, in app: XCUIApplication, line: UInt = #line) {
        let strip = app.descendants(matching: .any)[AccessibilityID.Viewer.strip]
        XCTAssertTrue(strip.satisfies("label == %@", label, within: 5), label, line: line)
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
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 30))
        XCTAssertFalse(app.buttons[AccessibilityID.Home.scan].isEnabled)
        try audit(app)
    }

    func testAuditAtLargestTextOfHomeWithScans() throws {
        let app = seededApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.allRow].appears(within: 5))
        try audit(app)
    }
}
