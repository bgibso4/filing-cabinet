// swift-tools-version: 6.4
import PackageDescription

// Settings shared by every module. ScreenModels and Screens add
// `.defaultIsolation(MainActor.self)` when they are created.
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
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        .target(name: "Core", swiftSettings: moduleSettings),
        .testTarget(name: "CoreTests", dependencies: ["Core"], swiftSettings: moduleSettings),
    ]
)
