import CoreGraphics
import os

/// Reads every page of a scan, in order, and derives the title and search text.
package struct ScanReader: Sendable {
    private let reader: any TextReader

    package init(reader: any TextReader) {
        self.reader = reader
    }

    /// A page that fails to read counts in `failedPages` and adds nothing. The title comes from page 1 only,
    /// so it is nil when page 1 fails. Cancelling the task stops reading before the next page.
    @concurrent
    package func read(_ pages: [CGImage]) async -> ScanReading {
        var texts: [PageText] = []
        var firstPage: PageText?
        var failed = 0
        for (index, page) in pages.enumerated() {
            // Stop once the caller has replaced the pages; the partial result is discarded anyway.
            if Task.isCancelled { break }
            let state = UnderstandingLog.signposter.beginInterval("OCR page")
            do {
                let text = try await reader.read(page)
                texts.append(text)
                if index == 0 { firstPage = text }
            } catch {
                // A page that failed because the task was cancelled is not a failed page.
                if !Task.isCancelled {
                    failed += 1
                    UnderstandingLog.logger.error("A page could not be read")
                }
            }
            UnderstandingLog.signposter.endInterval("OCR page", state)
        }
        let searchText = texts.flatMap(\.lines).map(\.text).joined(separator: "\n")
        return ScanReading(
            title: TitleRule.title(from: firstPage.map { [$0] } ?? []), searchText: searchText, failedPages: failed)
    }
}
