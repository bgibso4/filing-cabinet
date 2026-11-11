import Core
import Foundation
import Library
import Testing

/// Launch clears what an interrupted save left behind and every exported PDF (M20's safety net).
@MainActor
@Test func launchCleanupRemovesOrphansAndExports() async throws {
    let location = temporaryLocation()
    let files = PageFileStore(location: location, fileSystem: LocalFileSystem())
    let store = ScanStore(container: try ScanStore.makeContainer(storeURL: nil), files: files, clock: octoberTwelfth)
    let orphan = ScanID()
    _ = try await files.write([smallPage()], for: orphan)
    let exports = FileManager.default.temporaryDirectory.appending(path: "LaunchCleanupTests-\(UUID().uuidString)")
    let left = exports.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try Data([1]).write(to: left.appending(path: "Receipt.pdf"))

    await LaunchCleanup(store: store, export: ScanExport(files: files, folder: exports)).run()

    #expect(!exists(location.originals(for: orphan)))
    #expect(!exists(exports))
}
