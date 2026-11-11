import Core
import Library

// MARK: - Favorites' order (M8, M9)

extension CollectionGridModel {
    /// A tile's VoiceOver Favorite or Remove from Favorites: flips the scan's heart. A failed write shows the edit
    /// alert and changes nothing (P2). In Favorites, a kept tile favourited again goes back to its place rather than
    /// last, so a slip is one tap to undo (M9): a second write. Should only that one fail, the alert shows and the scan
    /// stays a favourite, last.
    package func toggleFavorite(_ id: ScanID) {
        let shown = built.shown
        guard let scan = shown.first(where: { $0.id == id }) else { return }
        let isFavorite = !scan.isFavorite
        do {
            try library.setFavorite(isFavorite, for: [id])
        } catch {
            editAlert = EditAlert()
            return
        }
        analytics.send(.favoritesChanged(isFavorite: isFavorite, count: 1))
        guard isFavorite && kind == .favorites else { return }
        do {
            try library.reorderFavorites(shown.filter { $0.isFavorite || $0.id == id }.map(\.id))
        } catch {
            editAlert = EditAlert()
        }
    }

    /// A drop in Favorites (M8): the tiles `sources` go just before `destination` (nil: at the end), and the store
    /// takes the favourites' new order (M3). A kept tile isn't a favourite (M9), so the store leaves it out and it
    /// stays in its place. A failed write shows the edit alert and changes nothing. True when the favourites' order
    /// changed (the drop's haptic); a drop that leaves it as it was writes nothing.
    @discardableResult
    package func moveFavorites(_ sources: [ScanID], before destination: ScanID?) -> Bool {
        let shown = built.shown
        let favorites = Set(Self.favoriteIDs(shown))
        let order = FavoriteReorder.order(shown.map(\.id), moving: sources, before: destination)
        guard order.filter(favorites.contains) != Self.favoriteIDs(shown) else { return false }
        do {
            try library.reorderFavorites(order)
        } catch {
            editAlert = EditAlert()
            return false
        }
        return true
    }

    /// VoiceOver's Move earlier: the favourite swaps places with the favourite before it (a kept tile isn't one).
    package func moveFavoriteEarlier(_ id: ScanID) {
        let favorites = Self.favoriteIDs(built.shown)
        guard let index = favorites.firstIndex(of: id), index > 0 else { return }
        moveFavorites([id], before: favorites[index - 1])
    }

    /// VoiceOver's Move later: the favourite swaps places with the favourite after it.
    package func moveFavoriteLater(_ id: ScanID) {
        let favorites = Self.favoriteIDs(built.shown)
        guard let index = favorites.firstIndex(of: id), index < favorites.count - 1 else { return }
        moveFavorites([id], before: favorites.indices.contains(index + 2) ? favorites[index + 2] : nil)
    }

    /// The favourites among `shown`, in its order.
    static func favoriteIDs(_ shown: [ScanSummary]) -> [ScanID] {
        shown.filter(\.isFavorite).map(\.id)
    }

    /// Favorites' tiles: the favourites in their order, with each scan shown before but no longer a favourite put back
    /// at its old index, while it is still in the library (M9).
    static func keepingUnfavorited(
        _ favorites: [ScanSummary], lastShown: [ScanID], visible: [ScanSummary]
    ) -> [ScanSummary] {
        let favoriteIDs = Set(favorites.map(\.id))
        let visibleByID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
        var shown = favorites
        for (index, id) in lastShown.enumerated() where !favoriteIDs.contains(id) {
            guard let kept = visibleByID[id] else { continue }
            shown.insert(kept, at: min(index, shown.count))
        }
        return shown
    }
}
