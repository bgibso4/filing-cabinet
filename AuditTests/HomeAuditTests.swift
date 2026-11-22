import Core
import XCTest

/// Home, empty and with scans, favourites or the cleanup banner, at the default and the largest text size.
@MainActor
final class HomeAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextHomeWithTheBanner() throws {
        let app = cleanedUpApp(largestText: true)
        try audit(app)
    }

    /// Scan stays disabled until launch ends. `-HoldScan` keeps it disabled after seeding, so the audit runs on a still
    /// Home. Auditing while 60 scans were still seeding failed on CI (runs 43120343687, 43134191294, 43421303926): the
    /// counts ticked and popped and the rows moved through the whole audit, and it reported 'Receipts' as low contrast
    /// though its own element screenshot reads black on white.
    func testAuditAtLargestTextOfDisabledScan() throws {
        let app = seededLibrary(largestText: true, flags: ["-HoldScan"])
        XCTAssertFalse(app.buttons[AccessibilityID.Home.scan].isEnabled)
        try audit(app)
    }

    func testAuditAtLargestTextOfHome() throws {
        let app = launchApp(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].appears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].isHittable)
        try audit(app)
    }

    func testAuditAtLargestTextOfHomeWithFavorites() throws {
        let app = favoritesApp(largestText: true)
        try audit(app)
    }

    func testAuditAtLargestTextOfHomeWithScans() throws {
        let app = seededLibrary(largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.allRow].appears(within: 5))
        try audit(app)
    }

    func testAuditHomeEmpty() throws {
        let app = launchApp()
        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.appears(within: 5))
        XCTAssertTrue(scan.isHittable)
        try audit(app)
    }

    func testAuditHomeWithFavorites() throws {
        let app = favoritesApp()
        try audit(app)
    }

    func testAuditHomeWithScans() throws {
        let app = seededLibrary()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.allRow].appears(within: 5))
        try audit(app)
    }

    func testAuditHomeWithTheBanner() throws {
        let app = cleanedUpApp()
        XCTAssertEqual(app.buttons[AccessibilityID.Home.cleanupBanner].label, "1 scan moved to Trash · View")
        try audit(app)
    }

    // MARK: Steps

    /// Twelve seeded scans on Oct 25, 2026, notes blocked: "Sample scan 10" went to Trash on its own since Home was
    /// last seen, so the banner shows. It shows only once seeding has finished, so waiting for it waits for every count.
    private func cleanedUpApp(largestText: Bool = false) -> XCUIApplication {
        let app = launchApp(
            ["-SeedScans", "12", "-FixedDate", "2026-10-25", "-Notifications", "denied"], largestText: largestText)
        XCTAssertTrue(
            app.buttons[AccessibilityID.Home.cleanupBanner].appears(within: seedingTimeout),
            "Home never showed the cleanup banner")
        return app
    }

    /// Six seeded scans, the first three favourites, every one landed: Wallet holds scans 1 and 6.
    private func favoritesApp(largestText: Bool = false) -> XCUIApplication {
        let app = launchApp(
            ["-SeedScans", "6", "-FixedDate", "2026-10-12", "-SeedFavorites", "3"], largestText: largestText)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.wallet)], count: 2)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.favoritesLink].appears(within: 5))
        let cards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.favoritePrefix))
        XCTAssertTrue(cards.firstMatch.appears(within: 5))
        return app
    }
}
