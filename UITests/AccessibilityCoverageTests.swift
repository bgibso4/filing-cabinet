import Core
import XCTest

@MainActor
final class AccessibilityCoverageTests: XCTestCase {
    func testEveryIdentifierIsOnScreen() {
        let app = launchApp()
        for id in AccessibilityID.all {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 5), id)
        }
    }

    func testEveryHomeButtonHasAnIdentifier() {
        let app = launchApp()
        XCTAssertTrue(app.buttons[AccessibilityID.scanButton].waitForExistence(timeout: 5))
        for button in app.buttons.allElementsBoundByIndex {
            XCTAssertFalse(button.identifier.isEmpty, button.label)
        }
    }
}
