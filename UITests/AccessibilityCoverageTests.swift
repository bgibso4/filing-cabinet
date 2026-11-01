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
}
