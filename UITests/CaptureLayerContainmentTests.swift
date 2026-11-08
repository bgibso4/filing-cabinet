import Core
import XCTest

/// The capture layer is a clear full-screen cover, so Home stays in the window under it. These prove it is out of the
/// accessibility tree while the camera or review is up (VoiceOver can't run on the simulator, so the tree is the
/// evidence), and fully back, and hittable, once the layer ends.
extension ScanJourneyTests {
    func testHomeIsHiddenUnderTheCaptureLayerAndBackAfterSaveAndDiscard() {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"])
        let scan = app.buttons[AccessibilityID.Home.scan]
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]

        // Under the camera, then under review.
        openCamera(in: app)
        assertHomeHidden(scan, row)
        app.buttons[AccessibilityID.Camera.fakeFinish].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Review.save].appears(within: 5))
        assertHomeHidden(scan, row)
        chooseReceipts(in: app)
        app.buttons[AccessibilityID.Review.save].tap()
        assertHomeBack(scan, row)

        scanOnePage(in: app)
        assertHomeHidden(scan, row)
        app.buttons[AccessibilityID.Review.close].tap()
        app.alerts["Discard this scan?"].buttons["Discard"].tap()
        assertHomeBack(scan, row)

        // The camera's own cancel ends the layer too.
        openCamera(in: app)
        app.buttons[AccessibilityID.Camera.fakeCancel].tap()
        assertHomeBack(scan, row)
    }

    private func openCamera(in app: XCUIApplication) {
        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.satisfies("isEnabled == true", within: 5))
        scan.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Camera.fakeFinish].appears(within: 5))
    }

    private func assertHomeHidden(_ scan: XCUIElement, _ row: XCUIElement, line: UInt = #line) {
        XCTAssertTrue(row.disappears(within: 5), "A Home row is in the tree under the layer", line: line)
        XCTAssertTrue(scan.disappears(within: 5), "Scan is in the tree under the layer", line: line)
    }

    private func assertHomeBack(_ scan: XCUIElement, _ row: XCUIElement, line: UInt = #line) {
        XCTAssertTrue(scan.appears(within: 10), line: line)
        XCTAssertTrue(row.appears(within: 5), line: line)
        XCTAssertTrue(scan.isHittable, line: line)
        XCTAssertTrue(row.isHittable, line: line)
    }
}
