import Core
import CoreGraphics
import Foundation
import Library
import Synchronization
import TestSupport
import Testing

/// Counts how many pages are open at once.
private final class OpenPages: Sendable {
    private struct Counts {
        var open = 0
        var mostAtOnce = 0
        var total = 0
    }

    private let counts = Mutex(Counts())

    var mostAtOnce: Int { counts.withLock { $0.mostAtOnce } }
    var total: Int { counts.withLock { $0.total } }

    func enter() {
        counts.withLock {
            $0.open += 1
            $0.total += 1
            $0.mostAtOnce = max($0.mostAtOnce, $0.open)
        }
    }

    func leave() { counts.withLock { $0.open -= 1 } }
}

private struct Fixture {
    let location = temporaryLocation()
    let files: PageFileStore
    let temporary: URL
    var folder: URL { temporary.appending(path: "Export") }
    let id = ScanID()
    let scan: ScanSummary

    init(pages: [CGImage]) async throws {
        files = PageFileStore(location: location, fileSystem: LocalFileSystem())
        temporary = FileManager.default.temporaryDirectory.appending(path: "ExportTests-\(UUID().uuidString)")
        _ = try await files.write(pages, for: id)
        scan = ScanSummary(
            id: id,
            title: "Receipt",
            collection: .receipts,
            scannedAt: .now,
            expiryOverride: nil,
            pageCount: pages.count
        )
    }

    func export(withPage: ScanExport.WithPage? = nil) -> ScanExport {
        ScanExport(files: files, folder: folder, withPage: withPage)
    }
}

private func pdfDocument(at url: URL) throws -> CGPDFDocument {
    try #require(CGPDFDocument(url as CFURL))
}

@Test func onePagePerScanPage() async throws {
    let fixture = try await Fixture(pages: [smallPage(), smallPage(), smallPage()])
    let url = try await fixture.export().pdf(for: fixture.scan, named: "Receipt")

    #expect(url.lastPathComponent == "Receipt.pdf")
    #expect(try pdfDocument(at: url).numberOfPages == 3)
}

@Test func pageShapeFollowsTheImage() async throws {
    let fixture = try await Fixture(pages: [smallPage()])  // 120 x 160
    let url = try await fixture.export().pdf(for: fixture.scan, named: "Receipt")

    let page = try #require(try pdfDocument(at: url).page(at: 1))
    let box = page.getBoxRect(.mediaBox)
    #expect(box.width == 612)
    #expect(abs(box.height - 816) < 1)
}

@Test func pagesAreJPEG() async throws {
    // Different pages, because a PDF writes identical images once.
    let taller = SyntheticPages.page(lines: [], size: CGSize(width: 120, height: 200))
    let fixture = try await Fixture(pages: [smallPage(), taller])
    let url = try await fixture.export().pdf(for: fixture.scan, named: "Receipt")

    let bytes = try Data(contentsOf: url)
    let text = try #require(String(data: bytes, encoding: .isoLatin1))
    #expect(text.components(separatedBy: "/DCTDecode").count - 1 == 2)
}

/// Proves pages are never open at the same time (scopes do not overlap), not that each is released from memory;
/// the phone check covers that.
@Test func pagesAreDrawnOneAtATime() async throws {
    let fixture = try await Fixture(pages: [smallPage(), smallPage(), smallPage(), smallPage()])
    let counter = OpenPages()
    let export = fixture.export { url, draw in
        counter.enter()
        defer { counter.leave() }
        try ScanExport.readOriginal(at: url, draw)
    }
    _ = try await export.pdf(for: fixture.scan, named: "Receipt")

    #expect(counter.total == 4)
    #expect(counter.mostAtOnce == 1)
}

@Test func fileNames() {
    #expect(ScanExport.fileName(for: "", taken: []) == "Scan")
    #expect(ScanExport.fileName(for: "   ", taken: []) == "Scan")
    #expect(ScanExport.fileName(for: "a/b", taken: []) == "a-b")
    #expect(ScanExport.fileName(for: "a:b", taken: []) == "a-b")
    #expect(ScanExport.fileName(for: "Receipt", taken: []) == "Receipt")
    #expect(ScanExport.fileName(for: "Receipt", taken: ["Receipt"]) == "Receipt 2")
    #expect(ScanExport.fileName(for: "Receipt", taken: ["Receipt", "Receipt 2"]) == "Receipt 3")
}

@Test func exportFolderIsRemoved() async throws {
    let fixture = try await Fixture(pages: [smallPage()])
    let export = fixture.export()
    let url = try await export.pdf(for: fixture.scan, named: "Receipt")
    #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))

    export.removeAll()

    #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    #expect(
        !FileManager.default.fileExists(atPath: fixture.temporary.appending(path: "Export").path(percentEncoded: false))
    )
}

@Test func pdfAppliesTheFileNameRules() async throws {
    let fixture = try await Fixture(pages: [smallPage()])
    let url = try await fixture.export().pdf(for: fixture.scan, named: "a/b")

    #expect(url.lastPathComponent == "a-b.pdf")
}

@Test func missingPageFileThrowsAndLeavesNothingBehind() async throws {
    let fixture = try await Fixture(pages: [smallPage()])
    let longer = ScanSummary(
        id: fixture.id,
        title: "Receipt",
        collection: .receipts,
        scannedAt: .now,
        expiryOverride: nil,
        pageCount: 2
    )

    await #expect(throws: LibraryError.pageMissing) {
        try await fixture.export().pdf(for: longer, named: "Receipt")
    }
    let left = try FileManager.default.contentsOfDirectory(at: fixture.folder, includingPropertiesForKeys: nil)
    #expect(left.isEmpty)
}
