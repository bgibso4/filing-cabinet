import Core
import XCTest

@MainActor
final class CameraAccessJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testDeniedCameraShowsOpenSettings() throws {
        let app = launchApp(["-CameraDenied"])
        let scan = tapScan(in: app)

        let openSettings = app.buttons[AccessibilityID.CameraOff.openSettings]
        XCTAssertTrue(openSettings.appears(within: 5))
        XCTAssertEqual(openSettings.label, "Open Settings")
        XCTAssertTrue(app.staticTexts["Camera access is off"].exists)
        assertIdentifiers(AccessibilityID.CameraOff.all, in: app)
        attachScreenshot(of: app, named: "camera-off-sheet")
        try audit(app)

        app.buttons[AccessibilityID.CameraOff.close].tap()
        XCTAssertTrue(openSettings.disappears(within: 5))
        XCTAssertTrue(scan.isHittable)
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

    func testCancelledCameraReturnsHome() {
        let app = launchApp(["-FakeCamera", "1"])
        let scan = tapScan(in: app)

        assertIdentifiers(AccessibilityID.Camera.all, in: app)
        app.buttons[AccessibilityID.Camera.fakeCancel].tap()
        XCTAssertTrue(scan.appears(within: 5))
        XCTAssertTrue(scan.isHittable)
        XCTAssertFalse(app.buttons[AccessibilityID.Camera.fakeCancel].exists)
    }

    /// Taps Scan once launch cleanup has enabled it.
    @discardableResult
    private func tapScan(in app: XCUIApplication) -> XCUIElement {
        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.satisfies("isEnabled == true", within: 5))
        scan.tap()
        return scan
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
