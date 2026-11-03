import Core
import Understanding
import XCTest

extension XCTestCase {
    /// One read of the pharmacy page by a fresh reader, timed and attached, never asserted (A14). Only meaningful
    /// as the first test in a fresh app launch: `make device-perf` runs each cold-read class on its own.
    func attachColdFirstRead(_ kind: ReaderKind) async throws {
        let page = try DeviceFixtures.page(DeviceFixtures.coldPage)
        let reader = ScanReader(reader: kind.makeReader())

        let start = ContinuousClock.now
        let reading = await reader.read([page])
        let elapsed = ContinuousClock.now - start

        XCTAssertEqual(reading.failedPages, 0, "the read failed, so its time means nothing")
        let milliseconds = Int(DeviceFixtures.milliseconds(elapsed).rounded())
        let attachment = XCTAttachment(string: "\(kind.rawValue) reader, cold first read: \(milliseconds) ms")
        attachment.name = "\(kind.rawValue)-cold-first-read"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
