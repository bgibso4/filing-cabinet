import Core
import Foundation
import Testing

@testable import Library

@Test(arguments: [
    ExpiryOverride.lifespan(.month),
    ExpiryOverride.lastDay(CalendarDay(year: 2027, month: 3, day: 3)),
    nil,
])
func recordRoundTripsTheOverride(_ override: ExpiryOverride?) {
    let record = ScanRecord()

    record.expiryOverride = override

    #expect(record.expiryOverride == override)
}

@Test func recordStoresTheOverrideAsRawValues() {
    let record = ScanRecord()

    record.expiryOverride = .lastDay(CalendarDay(year: 2027, month: 3, day: 3))
    #expect(record.overrideLastDay == 20_270_303)
    #expect(record.overrideLifespan == nil)

    record.expiryOverride = .lifespan(.month)
    #expect(record.overrideLifespan == "month")
    #expect(record.overrideLastDay == nil)
}

@Test func unknownCollectionHasNoSummary() {
    let record = ScanRecord()
    record.collectionKey = "nonsense"

    #expect(record.summary == nil)
}

@Test func summaryCarriesTheRecord() throws {
    let record = ScanRecord()
    record.title = "City Pharmacy"
    record.collectionKey = BuiltInCollection.receipts.rawValue
    record.scannedAt = Date(timeIntervalSince1970: 1_000)
    record.pageFileNames = ["page-1.heic", "page-2.heic"]
    record.expiryOverride = .lifespan(.week)

    let summary = try #require(record.summary)

    #expect(summary.id == ScanID(uuid: record.scanID))
    #expect(summary.title == "City Pharmacy")
    #expect(summary.collection == .receipts)
    #expect(summary.scannedAt == Date(timeIntervalSince1970: 1_000))
    #expect(summary.expiryOverride == .lifespan(.week))
    #expect(summary.pageCount == 2)
}
