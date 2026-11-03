import Core
import Foundation

/// A Sendable snapshot of one scan, safe to hand across isolation and to the screens.
package struct ScanSummary: Sendable, Hashable, Identifiable {
    package let id: ScanID
    package let title: String
    package let collection: BuiltInCollection
    package let scannedAt: Date
    package let expiryOverride: ExpiryOverride?
    package let pageCount: Int

    package init(
        id: ScanID,
        title: String,
        collection: BuiltInCollection,
        scannedAt: Date,
        expiryOverride: ExpiryOverride?,
        pageCount: Int
    ) {
        self.id = id
        self.title = title
        self.collection = collection
        self.scannedAt = scannedAt
        self.expiryOverride = expiryOverride
        self.pageCount = pageCount
    }
}
