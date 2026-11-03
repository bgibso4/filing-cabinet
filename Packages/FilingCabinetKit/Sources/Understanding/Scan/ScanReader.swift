import CoreGraphics
import os

/// Reads every page of a scan, in order, and derives the title and search text.
package struct ScanReader: Sendable {
    private let reader: any TextReader

    package init(reader: any TextReader) {
        self.reader = reader
    }

    /// A page that fails to read counts in `failedPages` and adds nothing.
    @concurrent
    package func read(_ pages: [CGImage]) async -> ScanReading {
        var texts: [PageText] = []
        var failed = 0
        for page in pages {
            let state = UnderstandingLog.signposter.beginInterval("OCR page")
            do {
                texts.append(try await reader.read(page))
            } catch {
                failed += 1
                UnderstandingLog.logger.error("A page could not be read")
            }
            UnderstandingLog.signposter.endInterval("OCR page", state)
        }
        let searchText = texts.flatMap(\.lines).map(\.text).joined(separator: "\n")
        return ScanReading(title: TitleRule.title(from: texts), searchText: searchText, failedPages: failed)
    }
}
