import Core
import XCTest

@MainActor
final class AccessibilityCoverageTests: XCTestCase {
    func testHomeIdentifiersAreOnScreen() {
        let app = launchApp()
        // Recent and All appear with a seeded library; they are checked from the seeded launch (Task 12).
        let emptyLibrary = AccessibilityID.Home.all.filter {
            $0 != AccessibilityID.Home.recentRow && $0 != AccessibilityID.Home.allRow
        }
        assertIdentifiers(emptyLibrary, in: app)
    }
}
