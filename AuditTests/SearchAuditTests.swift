import Core
import XCTest

/// Search with results and the keyboard down, at the default and the largest text size. The keyboard's own bar fails
/// the audit by itself (Plan 4, Task 1's spike), so it is put away first.
@MainActor
final class SearchAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextSearch() throws {
        let app = seededLibrary(largestText: true)
        searchAndPutTheKeyboardAway(in: app)
        try audit(app)
    }

    func testAuditSearchResults() throws {
        let app = seededLibrary()
        searchAndPutTheKeyboardAway(in: app)
        try audit(app)
    }

    // MARK: Steps

    /// Searches "page" (every seeded scan) and submits, which puts the keyboard away.
    private func searchAndPutTheKeyboardAway(in app: XCUIApplication) {
        openSearch(in: app).typeText("page\n")
        let results = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Search.resultPrefix))
        XCTAssertTrue(results.firstMatch.appears(within: 5))
        XCTAssertTrue(app.keyboards.firstMatch.disappears(within: 5))
    }
}
