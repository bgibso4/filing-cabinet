import Core
import CoreGraphics
import Foundation
import ImageIO

/// A scan as a PDF in the temporary folder (M10, M20): one page at a time, each page the page's own shape, 612 pt
/// wide, its image stored as JPEG at 0.85. Files live in `Export/<uuid>/` and are removed when the share ends and
/// at launch.
package struct ScanExport: Sendable {
    /// Opens one page file, hands the decoded page to `draw` and lets it go when `draw` returns: the seam tests use
    /// to watch how many pages are open at once.
    package typealias WithPage = @Sendable (URL, (CGImage) throws -> Void) throws -> Void

    /// M10: 612 pt (8.5 in) wide.
    private static let pageWidth: CGFloat = 612
    /// M10: JPEG at 0.85.
    private static let jpegQuality = 0.85

    private let files: PageFileStore
    private let folder: URL
    private let withPage: WithPage

    package init(
        files: PageFileStore,
        folder: URL = FileManager.default.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory),
        withPage: WithPage? = nil
    ) {
        self.files = files
        self.folder = folder
        self.withPage = withPage ?? { try Self.readOriginal(at: $0, $1) }
    }

    /// Writes `<name>.pdf` for the scan, one page drawn and released before the next is read.
    @concurrent
    package func pdf(for scan: ScanSummary, named name: String) async throws(LibraryError) -> URL {
        let directory = folder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        do {
            try FileManager().createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: "\(name).pdf")
            try write(files.originalURLs(pageCount: scan.pageCount, for: scan.id), to: url)
            return url
        } catch {
            let failure = LibraryError(error)
            LibraryLog.logger.error(
                "Exporting \(scan.pageCount, privacy: .public) pages failed (\(String(describing: failure))): \(error.localizedDescription, privacy: .private)"
            )
            remove(directory)
            throw failure
        }
    }

    /// Removes every exported file. Missing is fine.
    package func removeAll() {
        remove(folder)
    }

    /// The name (no extension) for a scan titled `title` among `taken` ones in one share (M10): an empty title is
    /// "Scan", "/" and ":" become "-", and a repeat gets " 2", " 3" and so on.
    package static func fileName(for title: String, taken: Set<String>) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let base = cleaned.isEmpty ? "Scan" : cleaned
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    /// The real page reader: decodes the HEIC original at `url` for `draw`.
    package static func readOriginal(at url: URL, _ draw: (CGImage) throws -> Void) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CocoaError(.fileReadNoSuchFile) }
        try draw(image)
    }

    private func write(_ pages: [URL], to url: URL) throws {
        guard let consumer = CGDataConsumer(url: url as CFURL),
            let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        for page in pages {
            try withPage(page) { try Self.draw($0, in: context) }
        }
        context.closePDF()
    }

    /// Re-encodes `image` as JPEG and draws that through a JPEG data provider, so the PDF keeps the JPEG stream.
    private static func draw(_ image: CGImage, in context: CGContext) throws {
        let jpeg = try ImageCoding.jpeg(image, quality: jpegQuality)
        guard let provider = CGDataProvider(data: jpeg as CFData),
            let page = CGImage(
                jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw ImageCoding.CodingError.encodeFailed }
        var box = CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * CGFloat(page.height) / CGFloat(page.width))
        context.beginPage(mediaBox: &box)
        context.draw(page, in: box)
        context.endPage()
    }

    private func remove(_ url: URL) {
        let files = FileManager()
        guard files.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            try files.removeItem(at: url)
        } catch {
            LibraryLog.logger.error(
                "Removing \(url.lastPathComponent, privacy: .private) failed: \(error.localizedDescription, privacy: .private)"
            )
        }
    }
}
