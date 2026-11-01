import Core
import XCTest

@MainActor
final class HomeJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testHomeShowsCollectionsAndScan() throws {
        let app = launchApp()
        for collection in BuiltInCollection.allCases {
            let row = app.descendants(matching: .any)[AccessibilityID.collectionRow(collection)]
            XCTAssertTrue(row.waitForExistence(timeout: 5), collection.rawValue)
        }
        XCTAssertTrue(app.buttons[AccessibilityID.scanButton].isHittable)
        XCTAssertEqual(app.buttons[AccessibilityID.scanButton].label, "Scan")
        try audit(app)
    }

    func testScanButtonHittableAtLargestText() {
        let app = launchApp(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons[AccessibilityID.scanButton].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.scanButton].isHittable)
    }
}
