import Core
import XCTest

/// The sheet that says camera access is off, at the default and the largest text size.
@MainActor
final class CameraOffAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextOfTheCameraOffSheet() throws {
        let app = launchApp(["-CameraDenied"], largestText: true)
        tapScan(in: app)
        XCTAssertTrue(app.buttons[AccessibilityID.CameraOff.openSettings].appears(within: 5))
        attachScreenshot(of: app, named: "camera-off-sheet-ax")
        try audit(app)
        // Scrolled to its end, the sheet keeps Close on its fixed header, clear of the text. The title can't scroll fully
        // out of view at this size, and the audit flags a title cut by the scroll edge, so this asserts Close instead.
        app.staticTexts[AccessibilityID.CameraOff.message].swipeUp()
        attachScreenshot(of: app, named: "camera-off-sheet-ax-scrolled")
        XCTAssertTrue(app.buttons[AccessibilityID.CameraOff.close].isHittable)
    }

    func testAuditTheCameraOffSheet() throws {
        let app = launchApp(["-CameraDenied"])
        tapScan(in: app)
        XCTAssertTrue(app.buttons[AccessibilityID.CameraOff.openSettings].appears(within: 5))
        attachScreenshot(of: app, named: "camera-off-sheet")
        try audit(app)
    }

    /// Taps Scan once launch cleanup has enabled it.
    private func tapScan(in app: XCUIApplication) {
        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.satisfies("isEnabled == true", within: 5))
        scan.tap()
    }
}
