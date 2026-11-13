import Foundation
import Testing
import UIKit

@testable import FilingCabinet

/// The app's own launch, in the app's process: M20's safety net removes the PDFs a share left in the temporary folder.
@MainActor
struct AppLaunchTests {
    @Test func launchRemovesExportedPDFs() async throws {
        let left = FileManager.default.temporaryDirectory.appending(path: "Export/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try Data([1]).write(to: left.appending(path: "Left.pdf"))
        // `-UITest` turns animations off for the process; the snapshot tests that follow keep theirs.
        let animations = UIView.areAnimationsEnabled
        defer { UIView.setAnimationsEnabled(animations) }
        let environment = try AppEnvironment.make(arguments: ["-UITest", "-Notifications", "authorized"])

        await environment.launch()

        #expect(!FileManager.default.fileExists(atPath: left.path(percentEncoded: false)))
    }
}
