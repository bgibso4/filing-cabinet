import CoreGraphics

/// A scroll a header screen asks for.
package enum HeaderScroll: Sendable, Equatable {
    /// To this offset of the content, as SwiftUI's scroll position measures it (0 is the top under the bar).
    case content(offset: CGFloat)
    /// To this raw top offset of the scroll view, above the top where SwiftUI's scroll position stops. The bar follows
    /// it as it follows a pull, so a collapsed bar expands.
    case scrollView(offset: CGFloat)
}

/// The scrolls a header screen makes by itself to rest as `rest` asks (plan 3, E1). A new screen's bar opens expanded,
/// so to rest small the content first scrolls by the bar's whole inset (more than any large title), which collapses the
/// bar, then back to its top once the inset has dropped: the scroll position keeps its offset across the bar's change,
/// which would leave the first rows under the bar. The scroll lands a report before the inset drops, so landing says
/// nothing.
///
/// A new screen resting large, or not scrolling, asks for nothing while its bar is expanded; one resting large that
/// doesn't scroll expands its bar whenever it is seen collapsed (see `expand`). A live change to large under
/// a collapsed bar (a grid emptied on screen) pulls the content down to the expanded bar's inset, which expands it as a
/// pull would. A live change to small settles again (Trash filling up).
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

    /// The scroll to make after a report of the bar's `inset` (already recorded in `insets`), if any.
    package mutating func target(insets: HeaderInsets, inset: CGFloat) -> HeaderScroll? {
        guard inset > 0, phase != .settled else { return nil }
        guard rest == .small, scrolls else { return expand(insets) }
        switch phase {
        case .unsettled:
            // A live change to small under a bar already collapsed: nothing to do.
            guard !insets.isCollapsed else {
                phase = .settled
                return nil
            }
            phase = .collapsing
            return .content(offset: inset)
        case .collapsing:
            guard inset < (insets.largest ?? inset) else { return nil }
            phase = .settled
            return .content(offset: 0)
        case .settled:
            return nil
        }
    }

    /// Resting large: a bar seen collapsed is expanded; one that is already expanded, or a new screen's, is left alone.
    /// Content that doesn't scroll keeps watching: nothing the person does there collapses the bar, but the system does
    /// on a push from a screen with a shorter large title (phone check F6: the bar opens at that title's height, then
    /// collapses).
    private mutating func expand(_ insets: HeaderInsets) -> HeaderScroll? {
        if scrolls { phase = .settled }
        guard insets.isCollapsed, let largest = insets.largest else { return nil }
        return .scrollView(offset: -largest)
    }
}
