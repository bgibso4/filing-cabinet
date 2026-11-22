import Core
import XCTest

@MainActor
final class CameraAccessJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testDeniedCameraShowsOpenSettings() {
        let app = launchApp(["-CameraDenied"])
        let scan = tapScan(in: app)

        let openSettings = app.buttons[AccessibilityID.CameraOff.openSettings]
        XCTAssertTrue(openSettings.appears(within: 5))
        XCTAssertEqual(openSettings.label, "Open Settings")
        XCTAssertTrue(app.staticTexts["Camera access is off"].exists)
        assertIdentifiers(AccessibilityID.CameraOff.all, in: app)
        attachScreenshot(of: app, named: "camera-off-sheet")

        app.buttons[AccessibilityID.CameraOff.close].tap()
        XCTAssertTrue(openSettings.disappears(within: 5))
        XCTAssertTrue(scan.isHittable)
    }

    func testCancelledCameraReturnsHome() {
        let app = launchApp(["-FakeCamera", "1"])
        let scan = tapScan(in: app)

        assertIdentifiers(AccessibilityID.Camera.all, in: app)
        app.buttons[AccessibilityID.Camera.fakeCancel].tap()
        // As long as every other wait for the layer to go: on a slow CI runner Home was still out of the tree after
        // 5 s, already on screen (run 43907743963). Scan is back in the tree as the layer starts to slide away (#80),
        // and can be tapped once it has gone.
        XCTAssertTrue(scan.satisfies("isHittable == true", within: 10))
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
