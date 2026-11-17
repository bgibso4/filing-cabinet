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
        scrolledToEnd: Bool = false,
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
            settle(window)
            if scrolledToEnd { scrollToEnd(of: window) }
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
    /// How far apart the draws compared after `settleTime` are, and how long they may go on differing.
    private static let stillInterval: TimeInterval = 0.25
    private static let stillTimeout: TimeInterval = 5

    /// Scrolls the screen's first scroll view to its end, for what a long screen keeps below the fold.
    private static func scrollToEnd(of window: UIWindow) {
        guard let scrollView = firstScrollView(in: window) else { return }
        let end = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height
        scrollView.setContentOffset(CGPoint(x: 0, y: max(0, end)), animated: false)
        settle(window)
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        return view.subviews.lazy.compactMap { firstScrollView(in: $0) }.first
    }

    /// Runs the main run loop so layout, the first commits and the glass's adaptation finish before the snapshot, then
    /// until two reads of every view's frame in a row match. A screen that lays out again after measuring itself
    /// (Details at the largest text) was once drawn mid-way on a slow CI runner, its panel a pixel high (run
    /// 44001660601). Frames, not draws: drawing the window to compare changed how the glass settled.
    private static func settle(_ window: UIWindow) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: settleTime))
        let deadline = Date(timeIntervalSinceNow: stillTimeout)
        var last = frames(in: window, of: window)
        while Date.now < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: stillInterval))
            let next = frames(in: window, of: window)
            if next == last { return }
            last = next
        }
    }

    private static func frames(in window: UIWindow, of view: UIView) -> [CGRect] {
        [view.convert(view.bounds, to: window)] + view.subviews.flatMap { frames(in: window, of: $0) }
    }
}

/// The app-hosted test found no window scene in its host app.
struct MissingWindowScene: Error {}
