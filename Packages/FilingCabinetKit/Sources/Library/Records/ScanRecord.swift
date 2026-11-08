import Core
import Foundation
import SwiftData

/// One saved scan in the store. Plain values only: every property has a default, nothing is unique and
/// there are no relationships, so later schema changes stay lightweight. Never leaves the main context;
/// hand out `summary` instead.
@Model
final class ScanRecord {
    var scanID: UUID = UUID()
    var title: String = ""
    /// A `BuiltInCollection.rawValue`.
    var collectionKey: String = ""
    var scannedAt: Date = Date.distantPast
    /// A `Lifespan.rawValue`; set only when the override is a lifespan.
    var overrideLifespan: String?
    /// A `CalendarDay.storageValue`; set only when the override is a last day.
    var overrideLastDay: Int?
    var pageFileNames: [String] = []
    var searchText: String = ""

    init() {}

    /// The scan's own expiry, stored as one of two raw columns. An unreadable column reads as no override.
    var expiryOverride: ExpiryOverride? {
        get {
            if let overrideLifespan, let lifespan = Lifespan(rawValue: overrideLifespan) {
                return .lifespan(lifespan)
            }
            if let overrideLastDay, let day = CalendarDay(storageValue: overrideLastDay) {
                return .lastDay(day)
            }
            return nil
        }
        set {
            switch newValue {
            case .lifespan(let lifespan):
                overrideLifespan = lifespan.rawValue
                overrideLastDay = nil
            case .lastDay(let day):
                overrideLifespan = nil
                overrideLastDay = day.storageValue
            case nil:
                overrideLifespan = nil
                overrideLastDay = nil
            }
        }
    }

    /// Nil when `collectionKey` names no built-in collection.
    var summary: ScanSummary? {
        guard let collection = BuiltInCollection(rawValue: collectionKey) else { return nil }
        return ScanSummary(
            id: ScanID(uuid: scanID),
            title: title,
            collection: collection,
            scannedAt: scannedAt,
            expiryOverride: expiryOverride,
            pageCount: pageFileNames.count
        )
    }
}
