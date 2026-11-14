import Core
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// The app's own Spotlight index, readable only while the phone is unlocked (A10), so no title shows in Lock Screen
/// search.
public struct CoreSpotlightIndex: SpotlightIndexing {
    private static let name = "scans"
    private static let domain = "scans"

    public init() {}

    public func index(_ items: [SpotlightItem]) async throws {
        try await Self.searchableIndex().indexSearchableItems(items.map(Self.searchableItem))
    }

    public func remove(_ ids: [ScanID]) async throws {
        try await Self.searchableIndex().deleteSearchableItems(withIdentifiers: ids.map(\.spotlightIdentifier))
    }

    public func removeAll() async throws {
        try await Self.searchableIndex().deleteAllSearchableItems()
    }

    /// Made for each call: the index isn't Sendable, and a named index is only a handle.
    private static func searchableIndex() -> CSSearchableIndex {
        CSSearchableIndex(name: name, protectionClass: .complete)
    }

    /// The title, the detail and the thumbnail; no text content and no keywords (A10).
    package static func searchableItem(_ item: SpotlightItem) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.displayName = item.title
        attributes.contentDescription = item.detail
        attributes.thumbnailData = item.thumbnail
        let searchable = CSSearchableItem(
            uniqueIdentifier: item.id.spotlightIdentifier, domainIdentifier: domain, attributeSet: attributes)
        // Without a date an item leaves search a month after it was indexed.
        searchable.expirationDate = item.expires ?? .distantFuture
        return searchable
    }
}
