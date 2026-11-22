import Core
import XCTest

/// A collection grid, and its select mode, at the default and the largest text size.
@MainActor
final class GridAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAGrid() throws {
        let app = seededLibrary()
        app.open(.receipts)
        XCTAssertGreaterThan(app.gridTiles.count, 0)
        try audit(app)
    }

    func testAuditAtLargestTextOfAGrid() throws {
        let app = seededLibrary(largestText: true)
        app.open(.receipts)
        XCTAssertGreaterThan(app.gridTiles.count, 0)
        try audit(app)
    }

    /// Select mode at the largest text size: the subtitle, the ticks and Move to Trash in Scan's place.
    func testAuditAtLargestTextOfSelectMode() throws {
        let app = seededLibrary(largestText: true)
        app.open(.receipts)
        let select = app.buttons[AccessibilityID.Grid.select]
        XCTAssertTrue(select.appears(within: 5))
        select.tap()
        app.gridTiles.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Grid.moveToTrash].isEnabled)
        try audit(app)
    }
}
