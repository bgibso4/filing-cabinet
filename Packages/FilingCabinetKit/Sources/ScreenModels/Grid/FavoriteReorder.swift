import Core

/// Where a drag in Favorites puts the tiles it moves (M8): the store then numbers them (M3).
package enum FavoriteReorder {
    /// `ids` with `sources` taken out and put back, in the order `ids` holds them, just before `destination`, or at the
    /// end when it is nil or not in `ids`. A destination that is itself moved stands for the first unmoved id after it,
    /// so dropping a tile on itself changes nothing. Ids not in `ids` are ignored.
    package static func order(_ ids: [ScanID], moving sources: [ScanID], before destination: ScanID?) -> [ScanID] {
        let moving = Set(sources)
        let moved = ids.filter(moving.contains)
        var staying = ids.filter { !moving.contains($0) }
        let target = destination.flatMap { destination in
            ids.drop { $0 != destination }.first { !moving.contains($0) }
        }
        let index = target.flatMap(staying.firstIndex(of:)) ?? staying.endIndex
        staying.insert(contentsOf: moved, at: index)
        return staying
    }
}
