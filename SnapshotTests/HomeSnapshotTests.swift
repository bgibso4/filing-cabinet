import ScreenModels
import Screens
import XCTest

final class HomeSnapshotTests: XCTestCase {
    @MainActor
    func testHomeFirstLaunch() throws {
        try SnapshotHost.assertScreen(HomeView(model: HomeModel(), onScan: {}), testName: "home_first")
    }
}
