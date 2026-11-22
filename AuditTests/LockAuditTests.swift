import Core
import XCTest

/// The lock's cover, after Face ID was cancelled so Unlock shows, at the default and the largest text size. Settings'
/// lock row is in `SettingsAuditTests`.
@MainActor
final class LockAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextTheCover() throws {
        let app = launchApp(["-SeedScans", "3", "-Lock", "on", "-Authenticator", "cancels"], largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        try audit(app)
    }

    func testAuditTheCover() throws {
        let app = launchApp(["-SeedScans", "3", "-Lock", "on", "-Authenticator", "cancels"])
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        try audit(app)
    }
}
