import SnapshotTesting
import SwiftUI
import UIKit

/// The one way a snapshot test renders a screen.
@MainActor
enum SnapshotHost {
    /// Snapshots `view` once per variant, each in a new window in the host app's scene (so the safe areas are the
    /// real ones). The window is torn down afterwards, so windows don't pile up across tests.
    static func assertScreen(
        _ view: some View,
        testName: String,
        variants: [SnapshotConfig.Variant] = SnapshotConfig.variants,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw MissingWindowScene()
        }
        for variant in variants {
            let window = UIWindow(windowScene: scene)
            defer {
                window.rootViewController = nil
                window.isHidden = true
            }
            let controller = UIHostingController(rootView: view.dynamicTypeSize(variant.size))
            controller.overrideUserInterfaceStyle = variant.style
            window.rootViewController = controller
            window.makeKeyAndVisible()
            let strategy = SnapshotConfig.strategy
            assertSnapshot(
                of: controller,
                as: strategy,
                named: variant.name,
                file: file,
                testName: testName,
                line: line
            )
        }
    }
}

/// The app-hosted test found no window scene in its host app.
struct MissingWindowScene: Error {}
