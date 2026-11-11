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
            // The text size as a trait too, not only in SwiftUI's environment: with the trait left at the device's
            // size, a text could now and then be drawn at that size inside an ax5 layout (#84).
            controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategory(variant.size)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            settle()
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

extension SnapshotHost {
    /// How long a new window runs before it is drawn. Liquid Glass adapts to what is behind it over a few frames; drawn
    /// at once, the glass was caught in one of two states from run to run.
    private static let settleTime: TimeInterval = 1

    /// Runs the main run loop so layout, the first commits and the glass's adaptation finish before the snapshot.
    private static func settle() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: settleTime))
    }
}

/// The app-hosted test found no window scene in its host app.
struct MissingWindowScene: Error {}
