import Core
import CoreSpotlight
import Foundation
import Library
import Testing

/// A10: Spotlight gets the title, the detail and the thumbnail, never the scan's text or words.
@Test func searchableItemHoldsTitlesOnly() throws {
    let id = ScanID()
    let thumbnail = Data([0xFF, 0xD8, 0xFF])
    let item = SpotlightItem(
        id: id, title: "City Pharmacy", detail: "Receipts · 3 pages", thumbnail: thumbnail, expires: nil)

    let searchable = CoreSpotlightIndex.searchableItem(item)

    #expect(searchable.uniqueIdentifier == id.spotlightIdentifier)
    #expect(searchable.domainIdentifier == "scans")
    let attributes = searchable.attributeSet
    #expect(attributes.displayName == "City Pharmacy")
    #expect(attributes.contentDescription == "Receipts · 3 pages")
    #expect(attributes.thumbnailData == thumbnail)
    #expect(attributes.textContent == nil)
    #expect(attributes.keywords == nil)
    #expect(attributes.title == nil)
}

@Test func searchableItemExpiresWhenTheScanEntersTrash() {
    let entry = Date(timeIntervalSince1970: 1_800_000_000)
    let expiring = SpotlightItem(id: ScanID(), title: "A", detail: "B", thumbnail: nil, expires: entry)
    let forever = SpotlightItem(id: ScanID(), title: "A", detail: "B", thumbnail: nil, expires: nil)

    #expect(CoreSpotlightIndex.searchableItem(expiring).expirationDate == entry)
    // Never the default, which drops an item a month after it was indexed.
    #expect(CoreSpotlightIndex.searchableItem(forever).expirationDate == .distantFuture)
}
