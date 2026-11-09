import CoreGraphics

/// The scrolls a header screen makes by itself to rest as `rest` asks (plan 3, E1). A new screen's bar opens expanded,
/// so to rest small the content first scrolls by the bar's whole inset (more than any large title), which collapses the
/// bar, then back to its top once the inset has dropped: the scroll position keeps its offset across the bar's change,
/// which would leave the first rows under the bar. The scroll lands a report before the inset drops, so landing says
/// nothing.
///
/// Resting large, or not scrolling, asks for nothing and leaves the bar as it is: a new screen's bar opens expanded, but a
/// live change to large under a collapsed bar doesn't expand it (not seen yet; Trash emptying in Task 5 will show). A
/// change to small on a screen that is showing settles again (Trash filling up).
package struct HeaderSettling: Sendable, Equatable {
    private enum Phase: Sendable, Equatable {
        case unsettled
        /// Scrolled by the bar's inset, waiting for it to collapse.
        case collapsing
        case settled
    }

    private var rest: HeaderRest
    private var scrolls: Bool
    private var phase = Phase.unsettled

    package init(rest: HeaderRest, scrolls: Bool) {
        self.rest = rest
        self.scrolls = scrolls
    }

    package mutating func update(rest: HeaderRest, scrolls: Bool) {
        guard rest != self.rest || scrolls != self.scrolls else { return }
        self.rest = rest
        self.scrolls = scrolls
        phase = .unsettled
    }

    /// The `y` to scroll the content to after a report of the bar's `inset` (already recorded in `insets`), if any.
    package mutating func target(insets: HeaderInsets, inset: CGFloat) -> CGFloat? {
        guard inset > 0, rest == .small, scrolls else { return nil }
        switch phase {
        case .unsettled:
            // A live change to small under a bar already collapsed: nothing to do.
            guard !insets.isCollapsed else {
                phase = .settled
                return nil
            }
            phase = .collapsing
            return inset
        case .collapsing:
            guard inset < (insets.largest ?? inset) else { return nil }
            phase = .settled
            return 0
        case .settled:
            return nil
        }
    }
}
