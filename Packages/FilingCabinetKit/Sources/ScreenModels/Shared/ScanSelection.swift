import Core
import Foundation

/// Select mode on a screen of scans (Trash, and the grids, #68): whether it is on and which scans are ticked. The
/// screen asks for what is selected among the scans it still shows, so a scan that leaves the screen (a purge, a move)
/// leaves the selection with it.
package struct ScanSelection: Sendable, Equatable {
    package private(set) var isSelecting = false
    private var ticked: Set<ScanID> = []

    package init() {}

    /// Select / Cancel. Either way the ticks are forgotten.
    package mutating func toggleSelecting() {
        isSelecting.toggle()
        ticked = []
    }

    /// Ticks or unticks a scan; nothing outside select mode.
    package mutating func toggle(_ id: ScanID) {
        guard isSelecting else { return }
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    /// The ticked scans among `shown`.
    package func selected(among shown: some Sequence<ScanID>) -> Set<ScanID> {
        ticked.intersection(shown)
    }

    /// An action ends select mode.
    package mutating func finish() {
        isSelecting = false
        ticked = []
    }

    /// "2 selected", the subtitle while selecting (M24).
    package static func selectedLine(_ count: Int) -> String {
        String(localized: "\(count) selected", bundle: #bundle)
    }
}
