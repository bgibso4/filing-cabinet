import Core
import XCTest

/// Trash: the grid, select mode, a trashed scan and an emptied Trash, at the default and the largest text size.
@MainActor
final class TrashAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextTrash() throws {
        let app = trashApp(largestText: true)
        openTrash(in: app)
        try audit(app)
    }

    func testAuditAtLargestTextTrashViewer() throws {
        let app = trashApp(largestText: true)
        openTrash(in: app)
        openFirstTile(in: app)
        // Audit entry 2 is scoped to the Trash screen by its header: under the viewer it is gone.
        XCTAssertFalse(app.header("Trash").exists)
        try audit(app)
    }

    func testAuditEmptyTrash() throws {
        let app = trashApp()
        openTrash(in: app)
        app.buttons[AccessibilityID.Trash.emptyTrash].tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Empty Trash", AccessibilityID.Trash.emptyTrash)
        ).firstMatch
        XCTAssertTrue(confirm.appears(within: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Trash is empty"].appears(within: 5))
        XCTAssertTrue(app.header("Trash", shows: .large, within: 5), "The large title isn't showing")
        try audit(app)
    }

    func testAuditTrash() throws {
        let app = trashApp()
        openTrash(in: app)
        try audit(app)
    }

    /// Audited before ticking: the audit reads the last ticked tile's caption as "contrast nearly passed", every run,
    /// though the same caption passes unticked (#79). The bar's glass buttons are an overlay since 2026-11-10, so the
    /// audit now names that caption instead of reporting it with no element under the Trash exemption.
    func testAuditTrashSelectMode() throws {
        let app = trashApp()
        openTrash(in: app)
        app.buttons[AccessibilityID.Trash.select].tap()
        XCTAssertTrue(app.buttons["Cancel"].appears(within: 5))
        try audit(app)
    }

    func testAuditTrashViewer() throws {
        let app = trashApp()
        openTrash(in: app)
        openFirstTile(in: app)
        XCTAssertEqual(app.descendants(matching: .any)[AccessibilityID.TrashViewer.header].label, "Trashed scan 5")
        try audit(app)
    }

    // MARK: Steps

    /// Six scans in the library and five in Trash, moved there 0 to 4 days ago. The Trash row reads "Trash" with no
    /// number until the last seeded scan has moved there, so this waits for the 5.
    private func trashApp(largestText: Bool = false) -> XCUIApplication {
        let app = launchApp(
            ["-SeedScans", "6", "-SeedTrash", "5", "-FixedDate", "2026-10-12"], largestText: largestText)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.trashRow], count: 5)
        return app
    }

    /// Trash, from Home's row, with its five tiles in.
    private func openTrash(in app: XCUIApplication) {
        app.buttons[AccessibilityID.Home.trashRow].tap()
        XCTAssertTrue(app.header("Trash").appears(within: 5))
        XCTAssertTrue(app.trashTiles.satisfies("count == %d", 5, within: 5))
    }

    /// The soonest-gone tile opens the Trash viewer.
    private func openFirstTile(in app: XCUIApplication) {
        app.trashTiles.firstMatch.tap()
        assertIdentifiers(AccessibilityID.TrashViewer.all, in: app)
    }
}
