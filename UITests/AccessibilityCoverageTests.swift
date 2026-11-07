import Core
import XCTest

@MainActor
final class AccessibilityCoverageTests: XCTestCase {
    func testHomeIdentifiersAreOnScreen() {
        let app = launchApp()
        // Recent and All appear with a seeded library; the seeded launch below checks them.
        let emptyLibrary = AccessibilityID.Home.all.filter {
            $0 != AccessibilityID.Home.recentRow && $0 != AccessibilityID.Home.allRow
        }
        assertIdentifiers(emptyLibrary, in: app)
    }

    func testSeededHomeIdentifiersAreOnScreen() {
        let app = launchApp(["-SeedScans", "12", "-FixedDate", "2026-10-12"])
        assertIdentifiers(AccessibilityID.Home.all, in: app)
    }
}
