import Testing

@testable import Core

@Test func aReadingOnThisMachineHasMemoryAndAPeakAtLeastAsHigh() throws {
    let reading = try #require(MemoryReading.current())
    #expect(reading.now > 0)
    #expect(reading.peak >= reading.now)
}
