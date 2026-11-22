import Core
import XCTest

/// The viewer and Details over it, at the default and the largest text size, and the viewer in dark mode.
@MainActor
final class ViewerAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextDetails() throws {
        let app = seededLibrary(largestText: true)
        openAReceipt(in: app)
        openDetails(in: app)
        try audit(app)
    }

    func testAuditAtLargestTextOfTheViewer() throws {
        let app = seededLibrary(largestText: true)
        app.openThreePageScan()
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)
        try audit(app)
    }

    func testAuditDetails() throws {
        let app = seededLibrary()
        openAReceipt(in: app)
        openDetails(in: app)
        try audit(app)
    }

    func testAuditTheViewer() throws {
        let app = seededLibrary()
        app.openThreePageScan()
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)
        try audit(app)
    }

    /// In dark mode the pill's whole detail line, time left included, is the primary colour (Ben, 2026-11-07).
    func testViewerAuditInDarkMode() throws {
        XCUIDevice.shared.appearance = .dark
        // A teardown block, not `defer`: a failure stops the test with an exception that skips `defer`.
        addTeardownBlock { @MainActor in XCUIDevice.shared.appearance = .light }
        let app = seededLibrary()
        app.openThreePageScan()
        try audit(app)
    }

    // MARK: Steps

    /// The seed's newest Receipts scan, one page.
    private func openAReceipt(in app: XCUIApplication) {
        app.open(.receipts)
        app.gridTiles.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
    }

    /// The header pill opens Details; the pill leaves VoiceOver once Details is up.
    private func openDetails(in app: XCUIApplication) {
        app.descendants(matching: .any)[AccessibilityID.Viewer.header].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Details.title].appears(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].disappears(within: 5))
    }
}
