import XCTest

/// Its own class so `make device-perf` can run it alone, first in a fresh app launch.
final class DocumentsReaderColdTests: XCTestCase {
    func testDocumentsReaderColdFirstRead() async throws {
        try await attachColdFirstRead(.documents)
    }
}
