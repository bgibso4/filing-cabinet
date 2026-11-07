import XCTest

/// Its own class so `make device-perf` can run it alone, first in a fresh app launch.
final class TextReaderColdTests: XCTestCase {
    func testTextReaderColdFirstRead() async throws {
        try await attachColdFirstRead(.text)
    }
}
