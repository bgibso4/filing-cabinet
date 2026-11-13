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
        .library(name: "Understanding", targets: ["Understanding"]),
        .library(name: "Library", targets: ["Library"]),
        .library(name: "ScreenModels", targets: ["ScreenModels"]),
        .library(name: "Screens", targets: ["Screens"]),
        .library(name: "TestSupport", targets: ["TestSupport"]),
    ],
    targets: [
        .target(name: "Core", swiftSettings: moduleSettings),
        .target(name: "Understanding", dependencies: ["Core"], swiftSettings: moduleSettings),
        .target(name: "Library", dependencies: ["Core"], swiftSettings: moduleSettings),
        .target(
            name: "TestSupport",
            dependencies: ["Core", "Understanding", "Library"],
            swiftSettings: moduleSettings
        ),
        .target(
            name: "ScreenModels",
            dependencies: ["Core", "Understanding", "Library"],
            resources: [.process("Localizable.xcstrings")],
            swiftSettings: moduleSettings + [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "Screens",
            dependencies: ["Core", "ScreenModels", "Library"],
            resources: [.process("Localizable.xcstrings"), .process("Resources/Tokens.xcassets")],
            swiftSettings: moduleSettings + [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "CoreTests", dependencies: ["Core", "TestSupport"], swiftSettings: moduleSettings),
        .testTarget(
            name: "UnderstandingTests",
            dependencies: ["Core", "Understanding", "TestSupport"],
            swiftSettings: moduleSettings
        ),
        .testTarget(
            name: "LibraryTests",
            dependencies: ["Core", "Library", "TestSupport"],
            resources: [.copy("Fixtures")],
            swiftSettings: moduleSettings
        ),
        // The made-up test set and the suggestion evaluation (Plan 5). The file checks and the report's scoring run
        // in Fast; the model run only in the SuggestionEvaluation scheme (`make eval-suggestions`).
        .testTarget(
            name: "SuggestionEvaluationTests",
            dependencies: ["Core", "Understanding"],
            resources: [.copy("Fixtures")],
            swiftSettings: moduleSettings
        ),
        // The reader bake-off (A12): a report, not a gate. Runs only in the ReaderComparison scheme on macOS.
        .testTarget(
            name: "ReaderComparisonTests",
            dependencies: ["Core", "Understanding"],
            exclude: ["expected.json"],
            swiftSettings: moduleSettings
        ),
        .testTarget(
            name: "ScreenModelsTests",
            dependencies: ["Core", "ScreenModels", "TestSupport"],
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
