// swift-tools-version: 6.4
import PackageDescription

// Settings shared by every module. ScreenModels and Screens add
// `.defaultIsolation(MainActor.self)`.
let moduleSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "FilingCabinetKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "ScreenModels", targets: ["ScreenModels"]),
        .library(name: "Screens", targets: ["Screens"]),
        .library(name: "TestSupport", targets: ["TestSupport"]),
    ],
    targets: [
        .target(name: "Core", swiftSettings: moduleSettings),
        .target(name: "Understanding", dependencies: ["Core"], swiftSettings: moduleSettings),
        .target(name: "TestSupport", dependencies: ["Core", "Understanding"], swiftSettings: moduleSettings),
        .target(
            name: "ScreenModels",
            dependencies: ["Core"],
            resources: [.process("Localizable.xcstrings")],
            swiftSettings: moduleSettings + [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "Screens",
            dependencies: ["Core", "ScreenModels"],
            resources: [.process("Localizable.xcstrings"), .process("Resources/Tokens.xcassets")],
            swiftSettings: moduleSettings + [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "CoreTests", dependencies: ["Core", "TestSupport"], swiftSettings: moduleSettings),
        .testTarget(
            name: "UnderstandingTests",
            dependencies: ["Understanding", "TestSupport"],
            swiftSettings: moduleSettings
        ),
        .testTarget(
            name: "ScreenModelsTests",
            dependencies: ["ScreenModels", "TestSupport"],
            swiftSettings: moduleSettings + [.defaultIsolation(MainActor.self)]
        ),
        // Runs on the simulator only (UIKit); it is not part of the Fast scheme.
        .testTarget(
            name: "ScreensTests",
            dependencies: ["Screens", "Core"],
            swiftSettings: moduleSettings + [.defaultIsolation(MainActor.self)]
        ),
    ]
)
