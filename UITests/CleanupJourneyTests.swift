import Core
import XCTest

/// Self-cleaning with notes blocked (02-04): scans that expired since Home was last seen are in Trash, Home's banner
/// counts them, and View opens Trash and clears it.
@MainActor
final class CleanupJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Seeding 12 scans takes a few seconds after the launch returns, longer on a CI runner (see TrashJourneyTests).
    /// Twelve seeded scans on Oct 25, 2026, notes blocked. Under `-UITest` Home was last seen 14 days before, so
    /// "Sample scan 10" (a Throwaway scanned Oct 16, kept a week) went to Trash on its own since then, on Oct 23.
    /// The banner shows only once seeding has finished, so waiting for it also waits for every count.
    private func cleanedUpApp(largestText: Bool = false) -> XCUIApplication {
        let app = launchApp(
            ["-SeedScans", "12", "-FixedDate", "2026-10-25", "-Notifications", "denied"], largestText: largestText)
        XCTAssertTrue(
            app.buttons[AccessibilityID.Home.cleanupBanner].waitForExistence(timeout: seedingTimeout),
            "Home never showed the cleanup banner")
        return app
    }

    func testExpiredScansReachTrashAndTheBannerShows() throws {
        let app = cleanedUpApp()
        let banner = app.buttons[AccessibilityID.Home.cleanupBanner]
        XCTAssertEqual(banner.label, "1 scan moved to Trash · View")
        XCTAssertEqual(app.buttons[AccessibilityID.Home.trashRow].label, "Trash, 1")
        assertIdentifiers([AccessibilityID.Home.cleanupBanner, AccessibilityID.Home.trashRow], in: app)
        try audit(app)

        banner.tap()
        XCTAssertTrue(app.staticTexts[AccessibilityID.Trash.header].waitForExistence(timeout: 5))
        let tiles = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(tiles.count, 1)
        // Entered Oct 23, so 28 of its 30 days are left.
        XCTAssertEqual(tiles.firstMatch.label, "Sample scan 10, Throwaways, 28 days left")

        // Back on Home the banner is gone: View cleared it.
        app.buttons[AccessibilityID.Grid.back].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.trashRow].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[AccessibilityID.Home.cleanupBanner].exists)
    }

    func testAuditAtLargestTextHomeWithTheBanner() throws {
        let app = cleanedUpApp(largestText: true)
        try audit(app)
    }
}
