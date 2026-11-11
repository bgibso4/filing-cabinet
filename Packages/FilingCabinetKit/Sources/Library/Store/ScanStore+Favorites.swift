import Core
import SwiftData

/// Favourites and the reads of recognized text (M1, M3).
extension ScanStore {
    public func setFavorite(_ isFavorite: Bool, for ids: [ScanID]) throws(LibraryError) {
        LibraryLog.logger.info(
            "Setting \(ids.count, privacy: .public) scans' favourite to \(isFavorite, privacy: .public): \(Self.list(ids), privacy: .public)"
        )
        try setFavoriteOrders(FavoriteNumbering.setting(isFavorite, for: ids, in: scans))
    }

    public func reorderFavorites(_ ids: [ScanID]) throws(LibraryError) {
        LibraryLog.logger.info("Reordering \(ids.count, privacy: .public) favourites")
        try setFavoriteOrders(
            FavoriteNumbering.reordering(
                ids, in: scans, lifespans: lifespans, today: clock.today, calendar: clock.calendar))
    }

    public func searchTexts() -> [ScanID: String] {
        var descriptor = FetchDescriptor<ScanRecord>()
        descriptor.propertiesToFetch = [\.scanID, \.searchText]
        do {
            let records = try fetch(context, descriptor)
            return Dictionary(records.map { (ScanID(uuid: $0.scanID), $0.searchText) }) { first, _ in first }
        } catch {
            LibraryLog.logger.error("Reading search text failed: \(error.localizedDescription, privacy: .private)")
            return [:]
        }
    }

    public func searchText(for id: ScanID) -> String? {
        record(for: id)?.searchText
    }

    /// Stores the favourite numbers `FavoriteNumbering` worked out, all or nothing; nothing to change writes nothing.
    private func setFavoriteOrders(_ orders: [ScanID: Int?]) throws(LibraryError) {
        guard !orders.isEmpty else { return }
        try edit(Array(orders.keys)) { record in
            if let order = orders[ScanID(uuid: record.scanID)] { record.favoriteOrder = order }
        }
    }
}
