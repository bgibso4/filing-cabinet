import Core
import CoreGraphics
import Synchronization
import Understanding
import XCTest

/// Warm reading time per page on the phone (A12, A14): one warm-up read, then the five fixtures measured.
final class ReaderTimingTests: XCTestCase {
    private static let readTimeout: TimeInterval = 600

    func testTextReaderPerPage() throws {
        try measurePerPage(.text)
    }

    func testDocumentsReaderPerPage() throws {
        try measurePerPage(.documents)
    }

    private func measurePerPage(_ kind: ReaderKind) throws {
        let pages = try DeviceFixtures.pages.map(DeviceFixtures.page)
        let reader = ScanReader(reader: kind.makeReader())
        _ = read([pages[0]], with: reader)

        var perPage: [Double] = []
        let metrics: [any XCTMetric] = [
            XCTClockMetric(),
            XCTOSSignpostMetric(subsystem: "com.cadre.filingcabinet", category: "Understanding", name: "OCR page"),
        ]
        measure(metrics: metrics) {
            let start = ContinuousClock.now
            let reading = read(pages, with: reader)
            perPage.append(DeviceFixtures.milliseconds(ContinuousClock.now - start) / Double(pages.count))
            XCTAssertEqual(reading?.failedPages, 0, "a page failed, so this iteration's time means less")
        }

        let mean = perPage.reduce(0, +) / Double(max(perPage.count, 1))
        let each = perPage.map { "\(Int($0.rounded()))" }.joined(separator: ", ")
        let attachment = XCTAttachment(
            string: "\(kind.rawValue) reader, warm per page: mean \(Int(mean.rounded())) ms (iterations: \(each) ms)")
        attachment.name = "\(kind.rawValue)-warm-per-page"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Reads the pages off the main thread and waits; `measure` blocks are synchronous.
    private func read(_ pages: [CGImage], with reader: ScanReader) -> ScanReading? {
        let result = ReadingBox()
        let done = expectation(description: "read")
        Task {
            let reading = await reader.read(pages)
            result.value.withLock { $0 = reading }
            done.fulfill()
        }
        wait(for: [done], timeout: Self.readTimeout)
        return result.value.withLock { $0 }
    }

    /// Carries a reading out of the task that produced it.
    private final class ReadingBox: Sendable {
        let value = Mutex<ScanReading?>(nil)
    }
}
