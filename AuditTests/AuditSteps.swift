import Core
import XCTest

/// The steps the audit tests share: how they reach the screen they audit. The journeys keep their own copies, as each
/// journey class always has.
extension XCTestCase {
    /// Twelve seeded scans on Oct 12, 2026, every one landed. Home's cleanup banner comes in as the last seeded scan
    /// lands, and an audit taken mid-way caught it half drawn (CI run 42500722527, "Contrast failed" on the banner), so
    /// this waits for the banner too.
    @MainActor
    func seededLibrary(largestText: Bool = false, flags: [String] = []) -> XCUIApplication {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"] + flags, largestText: largestText)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.receipts)], count: 3)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.cleanupBanner].appears(within: seedingTimeout))
        return app
    }

    /// A screenshot kept with the results, for what an audit saw.
    @MainActor
    func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIApplication {
    /// A collection's grid, from its Home row.
    func open(_ collection: BuiltInCollection) {
        let row = buttons[AccessibilityID.Home.collectionRow(collection)]
        XCTAssertTrue(row.appears(within: 5))
        row.tap()
        XCTAssertTrue(header(collection).appears(within: 5))
    }

    /// A collection grid's tiles.
    var gridTiles: XCUIElementQuery {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
    }

    /// Trash's tiles.
    var trashTiles: XCUIElementQuery {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix))
    }

    /// The seed's Documents scans have three pages: the first one, in the viewer.
    func openThreePageScan() {
        open(.documents)
        gridTiles.firstMatch.tap()
        XCTAssertTrue(descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
    }

    /// Settings, from Home's gear, once it can be tapped (with the lock on, the cover goes first).
    func openSettings() {
        let gear = buttons[AccessibilityID.Home.settings]
        XCTAssertTrue(gear.satisfies("isHittable == true", within: 5))
        gear.tap()
        XCTAssertTrue(buttons[AccessibilityID.Settings.collections].appears(within: 5))
    }
}
