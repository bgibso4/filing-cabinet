import Core
import CoreGraphics
import Foundation

/// A scan ready to save: everything the store needs to write its files and record.
package struct ScanDraft: Sendable {
    package let id: ScanID
    package let title: String
    package let collection: BuiltInCollection
    package let scannedAt: Date
    package let expiryOverride: ExpiryOverride?
    package let pages: [CGImage]
    /// Nil means reading has not finished yet; the text arrives later through `updateSearchText` (M2).
    package let searchText: String?

    package init(
        id: ScanID,
        title: String,
        collection: BuiltInCollection,
        scannedAt: Date,
        expiryOverride: ExpiryOverride?,
        pages: [CGImage],
        searchText: String?
    ) {
        self.id = id
        self.title = title
        self.collection = collection
        self.scannedAt = scannedAt
        self.expiryOverride = expiryOverride
        self.pages = pages
        self.searchText = searchText
    }
}
