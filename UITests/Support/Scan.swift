import Core
import XCTest

/// Taps Scan once launch has enabled it, then Finish on the fake camera, and waits for review.
@MainActor
func scanOnePage(in app: XCUIApplication) {
    let scan = app.buttons[AccessibilityID.Home.scan]
    let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: scan)
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
    scan.tap()
    let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
    XCTAssertTrue(finish.waitForExistence(timeout: 5))
    finish.tap()
    XCTAssertTrue(app.buttons[AccessibilityID.Review.save].waitForExistence(timeout: 5))
}
