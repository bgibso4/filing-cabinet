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

    /// The variants a comma-separated list names, in `variants`' order; every variant when the list is nil or empty.
    /// `make affected` and `make retest` pass "light,ax5" as `SNAPSHOT_VARIANTS`.
    static func variants(named list: String?) throws -> [Variant] {
        let names = (list ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if names.isEmpty { return variants }
        if let unknown = names.first(where: { name in !variants.contains { $0.name == name } }) {
            throw UnknownSnapshotVariant(name: unknown)
        }
        return variants.filter { names.contains($0.name) }
    }

    /// The variants this run draws, from `SNAPSHOT_VARIANTS`.
    static func variantsThisRun() throws -> [Variant] {
        try variants(named: ProcessInfo.processInfo.environment["SNAPSHOT_VARIANTS"])
    }

    // iPhone 17, portrait. SnapshotTesting needs the safe area and size spelled out; without them the
    // content would sit under the status bar.
    private static let device = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 402, height: 874),
        traits: UITraitCollection(displayScale: 3)
    )

    /// Every pixel must be within delta E 2 of the reference (spec §6).
    static let perceptualPrecision: Float = 0.98

    // Computed: Snapshotting is not Sendable, so it can't be a shared static.
    /// The library's image strategy, with `CPUImageMatch` checked first (see there for why).
    static var strategy: Snapshotting<UIViewController, UIImage> {
        var strategy = Snapshotting<UIViewController, UIImage>.image(
            on: device, drawHierarchyInKeyWindow: true, perceptualPrecision: perceptualPrecision
        )
        let libraryDiff = strategy.diffing.diffV2
        strategy.diffing.diffV2 = { old, new in
            CPUImageMatch.matches(old, new, perceptualPrecision: perceptualPrecision) ? nil : libraryDiff(old, new)
        }
        return strategy
    }
}
