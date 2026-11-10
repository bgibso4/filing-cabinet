import Core
import Foundation

/// How favourite numbers change (M3), shared by `ScanStore` and `FakeLibrary` so both follow one rule. Each function
/// takes every scan, Trash included, and returns only the scans whose `favoriteOrder` changes, with its new value
/// (nil: no longer a favourite). A tie, should one ever be stored, is renumbered 0…n−1 in reading order first (B11).
package enum FavoriteNumbering {
    /// New favourites go last, one past the highest number any favourite holds, in the order of `ids` (B8).
    /// Un-favouriting clears the number. A scan already as asked, or not among `scans`, is left alone.
    package static func setting(_ isFavorite: Bool, for ids: [ScanID], in scans: [ScanSummary]) -> [ScanID: Int?] {
        var orders = repairedOrders(in: scans)
        let known = Set(scans.map(\.id))
        if isFavorite {
            var next = (orders.values.max() ?? -1) + 1
            for id in unique(ids) where known.contains(id) && orders[id] == nil {
                orders[id] = next
                next += 1
            }
        } else {
            ids.forEach { orders[$0] = nil }
        }
        return changes(to: orders, from: scans)
    }

    /// Renumbers every favourite 0…n−1. Favourites out of the library on `today` (in Trash) keep their slots; the
    /// visible ones fill the other slots in the order of `ids`, then any visible favourite `ids` left out, in its old
    /// order. An id that isn't a visible favourite is ignored.
    package static func reordering(
        _ ids: [ScanID],
        in scans: [ScanSummary],
        lifespans: CollectionLifespans,
        today: CalendarDay,
        calendar: Calendar
    ) -> [ScanID: Int?] {
        let favorites = scans.filter(\.isFavorite).sorted(by: ScanSummary.favoritesOrder)
        let visible = favorites.filter { favorite in
            if case .library = favorite.place(lifespans: lifespans, today: today, in: calendar) { return true }
            return false
        }.map(\.id)
        let visibleSet = Set(visible)
        let given = unique(ids).filter(visibleSet.contains)
        let givenSet = Set(given)
        let newVisibleOrder = given + visible.filter { !givenSet.contains($0) }
        var nextVisible = newVisibleOrder.startIndex
        var orders: [ScanID: Int] = [:]
        for (slot, favorite) in favorites.enumerated() {
            guard visibleSet.contains(favorite.id) else {
                orders[favorite.id] = slot
                continue
            }
            orders[newVisibleOrder[nextVisible]] = slot
            nextVisible += 1
        }
        return changes(to: orders, from: scans)
    }

    /// Every favourite's number; when two share one, all of them renumbered 0…n−1 in reading order.
    private static func repairedOrders(in scans: [ScanSummary]) -> [ScanID: Int] {
        let favorites = scans.filter(\.isFavorite).sorted(by: ScanSummary.favoritesOrder)
        let numbers = favorites.compactMap(\.favoriteOrder)
        guard Set(numbers).count < numbers.count else {
            return Dictionary(uniqueKeysWithValues: zip(favorites.map(\.id), numbers))
        }
        return Dictionary(uniqueKeysWithValues: favorites.enumerated().map { ($1.id, $0) })
    }

    /// The scans whose number differs from `orders` (absent: not a favourite), with their new number.
    private static func changes(to orders: [ScanID: Int], from scans: [ScanSummary]) -> [ScanID: Int?] {
        var changes: [ScanID: Int?] = [:]
        for scan in scans where scan.favoriteOrder != orders[scan.id] {
            // `updateValue`, not a subscript: assigning nil through the subscript would drop the key.
            changes.updateValue(orders[scan.id], forKey: scan.id)
        }
        return changes
    }

    /// `ids` without repeats, first occurrence kept.
    private static func unique(_ ids: [ScanID]) -> [ScanID] {
        var seen: Set<ScanID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
