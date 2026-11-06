/// Which tiles to prefetch around the visible ones: a limited run past the edge the user is scrolling towards.
package enum GridPrefetchWindow {
    package enum Direction {
        case forward
        case backward
    }

    /// About three screens of a three-column grid. Well under `ThumbnailLoader`'s memory limit of 200, so a window
    /// never evicts what it just loaded or what is on screen.
    private static let tileCount = 36

    /// The indexes to prefetch, nearest the visible tiles first. Empty at the end of the list.
    package static func indexes(visible: ClosedRange<Int>, direction: Direction, total: Int) -> [Int] {
        switch direction {
        case .forward:
            let first = visible.upperBound + 1
            return first < total ? Array(first..<min(first + tileCount, total)) : []
        case .backward:
            let end = visible.lowerBound
            return end > 0 ? Array((max(end - tileCount, 0)..<end).reversed()) : []
        }
    }

    /// The edge that gained a tile shows where the user is heading. A tile leaving, or a jump that moves both edges
    /// outward, says nothing new.
    package static func direction(
        from previous: ClosedRange<Int>?, to visible: ClosedRange<Int>, current: Direction
    ) -> Direction {
        guard let previous else { return current }
        let grewDown = visible.upperBound > previous.upperBound
        let grewUp = visible.lowerBound < previous.lowerBound
        if grewDown == grewUp { return current }
        return grewDown ? .forward : .backward
    }
}
