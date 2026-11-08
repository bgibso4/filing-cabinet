import Core
import XCTest

/// Taps Scan once launch has enabled it, then Finish on the fake camera, and waits for review.
@MainActor
func scanOnePage(in app: XCUIApplication) {
    let scan = app.buttons[AccessibilityID.Home.scan]
    XCTAssertTrue(scan.satisfies("isEnabled == true", within: 5))
    scan.tap()
    let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
    XCTAssertTrue(finish.appears(within: 5))
    finish.tap()
    XCTAssertTrue(app.buttons[AccessibilityID.Review.save].appears(within: 5))
}
