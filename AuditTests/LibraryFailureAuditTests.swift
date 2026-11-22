import Core
import XCTest

/// The "Your library couldn't open" screen (#40), at the default and the largest text size. Each test launches a new
/// process, as the failure happens at launch.
@MainActor
final class LibraryFailureAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextOfTheFailureScreen() throws {
        let app = launchApp(["-FailLibraryOpen"], largestText: true, fresh: true)
        XCTAssertTrue(app.buttons[AccessibilityID.LibraryFailure.tryAgain].appears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.LibraryFailure.tryAgain].isHittable)
        attachScreenshot(of: app, named: "library-failure-ax")
        try audit(app)
    }

    func testAuditTheFailureScreen() throws {
        let app = launchApp(["-FailLibraryOpen"], fresh: true)
        XCTAssertTrue(app.buttons[AccessibilityID.LibraryFailure.tryAgain].appears(within: 5))
        attachScreenshot(of: app, named: "library-failure")
        try audit(app)
    }
}
