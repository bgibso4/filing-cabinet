import SnapshotTesting
import SwiftUI
import UIKit

/// How every snapshot is taken: the pinned simulator (iPhone 17, iOS 27.0, see the Makefile), light, dark
/// and the largest accessibility text size.
enum SnapshotConfig {
    struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let size: DynamicTypeSize
    }

    static let variants = [
        Variant(name: "light", style: .light, size: .large),
        Variant(name: "dark", style: .dark, size: .large),
        Variant(name: "ax5", style: .light, size: .accessibility5),
    ]

    // iPhone 17, portrait. SnapshotTesting needs the safe area and size spelled out; without them the
    // content would sit under the status bar.
    private static let device = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 402, height: 874),
        traits: UITraitCollection(displayScale: 3)
    )

    // Computed: Snapshotting is not Sendable, so it can't be a shared static.
    static var strategy: Snapshotting<UIViewController, UIImage> {
        .image(on: device, drawHierarchyInKeyWindow: true, perceptualPrecision: 0.98)
    }
}
