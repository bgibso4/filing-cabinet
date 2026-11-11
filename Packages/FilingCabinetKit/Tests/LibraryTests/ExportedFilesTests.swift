import Core
import Foundation
import Library
import Testing

/// One screen's exports (M20): ending them removes only that screen's PDFs, never another's.
private struct Exports {
    let files = PageFileStore(location: temporaryLocation(), fileSystem: LocalFileSystem())
    let folder = FileManager.default.temporaryDirectory.appending(path: "ExportedFilesTests-\(UUID().uuidString)")
    var export: ScanExport { ScanExport(files: files, folder: folder) }

    func scan() async throws -> ScanSummary {
        let id = ScanID()
        _ = try await files.write([smallPage()], for: id)
        return ScanSummary(
            id: id, title: "Receipt", collection: .receipts, scannedAt: .now, expiryOverride: nil, pageCount: 1)
    }
}

@Test func removingOnesExportsLeavesAnothersAlone() async throws {
    let exports = Exports()
    let scan = try await exports.scan()
    let mine = ExportedFiles(export: exports.export)
    let theirs = ExportedFiles(export: exports.export)
    let myPDF = try await mine.pdf(for: scan, named: "Receipt")
    let theirPDF = try await theirs.pdf(for: scan, named: "Receipt")

    mine.removeAll()

    #expect(!exists(myPDF.deletingLastPathComponent()))
    #expect(exists(theirPDF))
}

@Test func removingTwiceIsFine() async throws {
    let exports = Exports()
    let mine = ExportedFiles(export: exports.export)
    let pdf = try await mine.pdf(for: try await exports.scan(), named: "Receipt")

    mine.removeAll()
    mine.removeAll()

    #expect(!exists(pdf))
}
