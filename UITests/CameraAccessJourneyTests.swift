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
        XCTAssertTrue(openSettings.waitForExistence(timeout: 5))
        XCTAssertEqual(openSettings.label, "Open Settings")
        XCTAssertTrue(app.staticTexts["Camera access is off"].exists)
        assertIdentifiers(AccessibilityID.CameraOff.all, in: app)
        attachScreenshot(of: app, named: "camera-off-sheet")
        try audit(app)

        app.buttons[AccessibilityID.CameraOff.close].tap()
        XCTAssertTrue(openSettings.waitForNonExistence(timeout: 5))
        XCTAssertTrue(scan.isHittable)
    }

    func testDeniedCameraSheetAuditAtLargestText() throws {
        let app = launchApp(["-CameraDenied"], largestText: true)
        tapScan(in: app)
        XCTAssertTrue(app.buttons[AccessibilityID.CameraOff.openSettings].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "camera-off-sheet-ax")
        try audit(app)
    }

    func testCancelledCameraReturnsHome() {
        let app = launchApp(["-FakeCamera", "1"])
        let scan = tapScan(in: app)

        assertIdentifiers(AccessibilityID.Camera.all, in: app)
        app.buttons[AccessibilityID.Camera.fakeCancel].tap()
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        XCTAssertTrue(scan.isHittable)
        XCTAssertFalse(app.buttons[AccessibilityID.Camera.fakeCancel].exists)
    }

    /// Taps Scan once launch cleanup has enabled it.
    @discardableResult
    private func tapScan(in app: XCUIApplication) -> XCUIElement {
        let scan = app.buttons[AccessibilityID.Home.scan]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: scan)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
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
