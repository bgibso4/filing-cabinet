import Screens
import XCTest

/// The lock cover (library-lock mocks, Mock 1): the app's mark, name and "Locked" on Home's ground. Without the Unlock
/// button, as it shows while Face ID runs and under the capture layer; with it, after a cancelled or failed Face ID,
/// light, dark and at the largest text.
final class LockCoverSnapshotTests: XCTestCase {
    @MainActor
    func testCover() throws {
        let variants = SnapshotConfig.variants.filter { $0.name != "ax5" }
        try SnapshotHost.assertScreen(
            LockCover(showsUnlock: false, onUnlock: {}), testName: "lock_cover", variants: variants)
    }

    @MainActor
    func testCoverWithUnlock() throws {
        try SnapshotHost.assertScreen(LockCover(showsUnlock: true, onUnlock: {}), testName: "lock_cover_unlock")
    }
}
