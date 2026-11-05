import Core
import Foundation

/// A Sendable snapshot of one scan, safe to hand across isolation and to the screens.
public struct ScanSummary: Sendable, Hashable, Identifiable {
    public let id: ScanID
    package let title: String
    package let collection: BuiltInCollection
    package let scannedAt: Date
    package let expiryOverride: ExpiryOverride?
    package let pageCount: Int

    public init(
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
