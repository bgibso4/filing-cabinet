import Core
import XCTest

/// Search end to end (Plan 4, Task 9): Home's field opens Search, results open the viewer, and what you opened and
/// searched for comes back before typing. Seeded scans are "Sample scan 1" (newest) to "Sample scan 12", cycling
/// Wallet, Receipts, Notes, Documents, Throwaways; each one's text is its title and "Page 1" (to "Page 3" in
/// Documents), so "scan 4" is in one scan, in Documents, and "scan 8" in one, in Notes.
@MainActor
final class SearchJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSearchFindsAScanByItsText() throws {
        let app = seededApp()
        let field = openSearch(in: app)
        XCTAssertTrue(app.keyboards.firstMatch.appears(within: 5), "the field is focused on arrival")
        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.satisfies(within: 5) { !($0.exists && $0.isHittable) }, "Search has no Scan")

        field.typeText("scan 4")
        let first = results(in: app).firstMatch
        XCTAssertTrue(
            first.satisfies("label == %@", "Sample scan 4, Documents, October 9, Sample scan 4", within: 5), first.label
        )
        XCTAssertEqual(results(in: app).count, 1)
        first.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))

        app.buttons[AccessibilityID.Viewer.back].tap()
        XCTAssertTrue(first.appears(within: 5), "back shows the results")
        XCTAssertEqual(field.value as? String, "scan 4")
        // With the keyboard down: its own buttons (Emoji) have no identifiers.
        XCTAssertTrue(app.keyboards.firstMatch.disappears(within: 5), "back from the viewer, the keyboard stays down")
        assertIdentifiers(AccessibilityID.Search.all + [AccessibilityID.Search.clearQuery], in: app)
        try audit(app)

        closeSearch(in: app)
        openSearch(in: app)
        let recent = app.buttons[AccessibilityID.Search.recent(0)]
        XCTAssertTrue(recent.satisfies("label == %@", "scan 4", within: 5), recent.label)
        let viewed = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Search.viewedPrefix)
        ).firstMatch
        XCTAssertTrue(viewed.satisfies("label == %@", "Sample scan 4", within: 5), viewed.label)
        closeSearch(in: app)
    }

    /// A hidden word finds a scan its page never says (Plan 5, Task 7): seeded Wallet scans hold "ID", so "ID" finds
    /// scans 1, 6 and 11, and the row reads "Matches ID".
    func testSearchFindsAScanByAHiddenWord() {
        let app = seededApp()
        let field = openSearch(in: app)
        field.typeText("ID")
        let first = results(in: app).firstMatch
        XCTAssertTrue(
            first.satisfies("label == %@", "Sample scan 1, Wallet, October 12, Matches ID", within: 5), first.label)
        XCTAssertEqual(results(in: app).count, 3)
        closeSearch(in: app)
    }

    /// With Reduce Motion, Search fades rather than slides, and the X's fade is its only way back to Home (a full-screen
    /// cover can't be swiped away), so its completion must land: open, type, a result and back, then the X (I4).
    func testReduceMotionSearchClosesToHome() {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12", "-ReduceMotion"])
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 3)
        openSearch(in: app).typeText("scan 4")
        let first = results(in: app).firstMatch
        XCTAssertTrue(first.appears(within: 5))
        first.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
        app.buttons[AccessibilityID.Viewer.back].tap()
        XCTAssertTrue(first.appears(within: 5), "back shows the results")
        closeSearch(in: app)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.search].isHittable, "Home takes taps again")
    }

    /// M17: nothing in the chosen collection, though Notes has it, and Search all scans finds it there.
    func testFilterAndSearchAll() {
        let app = seededApp()
        let field = openSearch(in: app)
        field.typeText("scan 8\n")
        XCTAssertTrue(results(in: app).firstMatch.satisfies("label BEGINSWITH %@", "Sample scan 8,", within: 5))

        let wallet = app.buttons[AccessibilityID.Search.chip(.wallet)]
        wallet.tap()
        XCTAssertTrue(wallet.isSelected)
        XCTAssertTrue(app.staticTexts["No results in Wallet"].appears(within: 5))
        XCTAssertTrue(app.staticTexts["1 scan in Notes mentions “scan 8”."].exists)
        XCTAssertEqual(results(in: app).count, 0)

        app.buttons[AccessibilityID.Search.searchAll].tap()
        XCTAssertTrue(results(in: app).firstMatch.satisfies("label BEGINSWITH %@", "Sample scan 8,", within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Search.chip(nil)].isSelected)
        XCTAssertFalse(wallet.isSelected)
        closeSearch(in: app)
    }

    /// A recent search fills the field; Clear empties the list (M5).
    func testClearRemovesRecentSearches() {
        let app = seededApp()
        openSearch(in: app).typeText("page\n")
        XCTAssertTrue(results(in: app).firstMatch.appears(within: 5))
        app.buttons[AccessibilityID.Search.close].tap()

        let field = openSearch(in: app)
        let recent = app.buttons[AccessibilityID.Search.recent(0)]
        XCTAssertTrue(recent.satisfies("label == %@", "page", within: 5), recent.label)
        recent.tap()
        XCTAssertTrue(field.satisfies("value == %@", "page", within: 5))
        XCTAssertTrue(results(in: app).firstMatch.appears(within: 5))

        app.buttons[AccessibilityID.Search.close].tap()
        openSearch(in: app)
        let clear = app.buttons[AccessibilityID.Search.clear]
        XCTAssertTrue(clear.appears(within: 5))
        clear.tap()
        XCTAssertTrue(recent.disappears(within: 5))
        XCTAssertFalse(clear.exists)
        closeSearch(in: app)
    }

    /// At the largest text, with results and the keyboard down: the keyboard's suggestion bar fails the audit by
    /// itself (Task 1's spike), so the search is submitted first.
    func testAuditAtLargestTextSearch() throws {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"], largestText: true)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 3)
        openSearch(in: app).typeText("page\n")
        XCTAssertTrue(results(in: app).firstMatch.appears(within: 5))
        XCTAssertTrue(app.keyboards.firstMatch.disappears(within: 5))
        try audit(app)
        closeSearch(in: app)
    }

    // MARK: Steps

    /// Twelve seeded scans, every one landed.
    private func seededApp() -> XCUIApplication {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"])
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 3)
        return app
    }

    /// Taps Home's field; Search's own field.
    @discardableResult
    private func openSearch(in app: XCUIApplication) -> XCUIElement {
        let homeField = app.buttons[AccessibilityID.Home.search]
        XCTAssertTrue(homeField.appears(within: 5))
        homeField.tap()
        let field = app.textFields[AccessibilityID.Search.field]
        XCTAssertTrue(field.appears(within: 5))
        return field
    }

    /// The X, back to Home resting large. Every test ends on Home, so the next one's relaunch never has to take a
    /// presented cover down.
    private func closeSearch(in app: XCUIApplication) {
        app.buttons[AccessibilityID.Search.close].tap()
        XCTAssertTrue(app.header("Filing Cabinet", shows: .large, within: 5), "the X returns to Home, resting large")
    }

    private func results(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Search.resultPrefix))
    }
}
