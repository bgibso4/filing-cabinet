import ScreenModels
import Screens
import SnapshotTesting
import SwiftUI
import XCTest

final class HomeSnapshotTests: XCTestCase {
    @MainActor
    func testHomeFirstLaunch() throws {
        // A window in the host app's scene, so the safe areas (status bar, home indicator) are the real ones.
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "the app-hosted test needs the host's window scene"
        )
        let window = UIWindow(windowScene: scene)
        for variant in SnapshotConfig.variants {
            let root = HomeView(model: HomeModel(), onScan: {}).dynamicTypeSize(variant.size)
            let controller = UIHostingController(rootView: root)
            controller.overrideUserInterfaceStyle = variant.style
            window.rootViewController = controller
            window.makeKeyAndVisible()
            assertSnapshot(of: controller, as: SnapshotConfig.strategy, named: variant.name, testName: "home_first")
        }
    }
}
