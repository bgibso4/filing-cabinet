import Core
import XCTest

/// The viewer's Share and More (Plan 4, Task 11): Share opens the system share sheet with the scan as a PDF, More holds
/// Save to Photos, Save to Files and Copy Text, and a scan opened from Trash has neither. The share sheet, menus and
/// alerts are never snapshotted, so they are attached as screenshots.
@MainActor
final class ExportJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testMoreMenuOffersThreeActions() {
        let app = seededApp()
        // A document, so its three pages show the strip too.
        openFromAllScans("Sample scan 4", in: app)
        assertIdentifiers(AccessibilityID.Viewer.all, in: app)

        app.buttons[AccessibilityID.Viewer.more].tap()
        let copyText = menuItem("Copy Text", in: app)
        XCTAssertTrue(copyText.appears(within: 5))
        let items = ["Save to Photos", "Save to Files", "Copy Text"].map { menuItem($0, in: app) }
        XCTAssertTrue(items.allSatisfy(\.exists))
        // Top to bottom, in 06-03's order.
        XCTAssertEqual(items.map(\.frame.minY), items.map(\.frame.minY).sorted())
        // Seeded scans have text, so Copy Text is on.
        XCTAssertTrue(copyText.isEnabled)
        attachScreenshot("More menu", of: app)

        copyText.tap()
        XCTAssertTrue(copyText.disappears(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].exists, "no note, no new screen")
    }

    func testSaveToPhotosDeniedShowsTheAlert() {
        let app = seededApp(["-Photos", "denied"])
        openFromAllScans("Sample scan 2", in: app)

        app.buttons[AccessibilityID.Viewer.more].tap()
        let save = menuItem("Save to Photos", in: app)
        XCTAssertTrue(save.appears(within: 5))
        save.tap()

        let alert = app.alerts["Photos access is off"]
        XCTAssertTrue(alert.appears(within: 5))
        XCTAssertTrue(alert.buttons["Open Settings"].exists)
        attachScreenshot("Photos access is off", of: app)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(alert.disappears(within: 5))
    }

    func testShareOpensTheShareSheet() {
        let app = seededApp()
        openFromAllScans("Sample scan 2", in: app)

        let share = app.buttons[AccessibilityID.Viewer.share]
        XCTAssertEqual(share.label, "Share")
        share.tap()

        // The sheet's header names what is shared after the scan (M10).
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.appears(within: 10))
        let caption = app.otherElements["LP.CaptionBar.TopCaption"]
        XCTAssertTrue(caption.satisfies("label == %@", "Sample scan 2", within: 10))
        attachScreenshot("Share sheet", of: app)

        // The sheet's own Close isn't in the tree; a tap above the half-height sheet closes it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(sheet.disappears(within: 5))
        XCTAssertTrue(share.isHittable)
    }

    /// A scan in Trash is read-only: no Share, no More.
    func testTrashViewerHasNoShareOrMore() {
        let app = launchApp(["-SeedScans", "6", "-SeedTrash", "2", "-FixedDate", "2026-10-12"])
        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        waitForSeeding(of: trashRow, count: 2)
        trashRow.tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix)
        )
        .firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        tile.tap()
        assertIdentifiers(AccessibilityID.TrashViewer.all, in: app)

        XCTAssertFalse(app.buttons[AccessibilityID.Viewer.share].exists)
        XCTAssertFalse(app.buttons[AccessibilityID.Viewer.more].exists)
    }

    /// Six seeded scans, all landed.
    private func seededApp(_ flags: [String] = []) -> XCUIApplication {
        let app = launchApp(["-SeedScans", "6", "-FixedDate", "2026-10-12"] + flags)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.wallet)], count: 2)
        return app
    }

    /// From Home, All Scans, then the scan titled `title`, in the viewer.
    private func openFromAllScans(_ title: String, in app: XCUIApplication) {
        let all = app.buttons[AccessibilityID.Home.allRow]
        XCTAssertTrue(all.appears(within: 5))
        all.tap()
        let tile = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", AccessibilityID.Grid.tilePrefix, "\(title),"
            )
        ).firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        tile.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
    }

    /// A menu item by its title: a `UIMenu`'s items carry no identifiers.
    private func menuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// The share sheet, menus and alerts are never snapshotted: a screenshot is kept for review instead.
    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
