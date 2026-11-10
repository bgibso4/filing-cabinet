import CoreGraphics

/// A scroll a header screen asks for.
package enum HeaderScroll: Sendable, Equatable {
    /// To this offset of the content, as SwiftUI's scroll position measures it (0 is the top under the bar).
    case content(offset: CGFloat)
    /// To this raw top offset of the scroll view, above the top where SwiftUI's scroll position stops. The bar follows
    /// it as it follows a pull, so a collapsed bar expands.
    case scrollView(offset: CGFloat)
    /// As `scrollView`, at once and only while a push brings the screen in, in time for UIKit to see it as the push
    /// starts; the content goes back to its top under the bar when the push ends (`ScrollViewOffset`).
    case pullDuringPush(offset: CGFloat)
}

/// The scrolls a header screen makes by itself to rest as `rest` asks (plan 3, E1). A new screen's bar opens expanded,
/// so to rest small the content first scrolls by the bar's whole inset (more than any large title), which collapses the
/// bar, then back to its top once the inset has dropped: the scroll position keeps its offset across the bar's change,
/// which would leave the first rows under the bar. The scroll lands a report before the inset drops, so landing says
/// nothing.
///
/// A new screen resting large pulls its content down once as a push brings it in, so the push doesn't collapse its bar
/// (see `arrive`), and expands its bar if the system collapses it anyway before the person has scrolled (see `expand`).
/// A live change to large under a collapsed bar (a grid emptied on screen) pulls the content down to the expanded bar's
/// inset, which expands it as a pull would. A live change to small settles again (Trash filling up).
package struct HeaderSettling: Sendable, Equatable {
    private enum Phase: Sendable, Equatable {
        /// A new screen resting large, before its first report of the bar (see `arrive`).
        case arriving
        /// A new screen resting large, until the person scrolls: the system may still collapse its bar (see `expand`).
        case watching
        case unsettled
        /// Scrolled by the bar's inset, waiting for it to collapse.
        case collapsing
        case settled
    }

    private var rest: HeaderRest
    private var scrolls: Bool
    private var phase: Phase

    package init(rest: HeaderRest, scrolls: Bool) {
        self.rest = rest
        self.scrolls = scrolls
        phase = rest == .large ? .arriving : .unsettled
    }

    package mutating func update(rest: HeaderRest, scrolls: Bool) {
        guard rest != self.rest || scrolls != self.scrolls else { return }
        self.rest = rest
        self.scrolls = scrolls
        phase = .unsettled
    }

    /// Ends a new screen's watch for the system collapsing its bar (see `expand`): the person has touched the scroll
    /// view, so what the bar does now is theirs (review N1), or another screen has been pushed over this one, whose bar
    /// it shares (N2). F6's collapse comes as the screen arrives, before either.
    package mutating func stopWatching() {
        if phase == .arriving || phase == .watching { phase = .settled }
    }

    /// The scroll to make after a report of the bar's `inset` (already recorded in `insets`), if any.
    package mutating func target(insets: HeaderInsets, inset: CGFloat) -> HeaderScroll? {
        guard inset > 0, phase != .settled else { return nil }
        guard rest == .small, scrolls else { return expand(insets, inset: inset) }
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
        case .arriving, .watching, .settled:
            return nil
        }
    }

    /// A new screen resting large, on its first report: it lays out under the bar of the screen it was pushed from, and
    /// UIKit collapses the bar for the whole push when the screen's own large header is taller (an empty grid's has a
    /// subtitle; Home's hasn't) and the content isn't above its top. Pulled down by a large title's height, the content
    /// is above its top whatever the difference (a subtitle's line is shorter than the title's), so the bar opens to
    /// the screen's own height (plan 3, E9, measured). A screen not being pushed (Home, a snapshot) ignores the pull.
    private mutating func arrive(_ insets: HeaderInsets, inset: CGFloat) -> HeaderScroll? {
        phase = .watching
        guard insets.largeTitleHeight > 0 else { return nil }
        return .pullDuringPush(offset: -(inset + insets.largeTitleHeight))
    }

    /// Resting large: a bar seen collapsed is expanded; one that is already expanded is left alone. A new screen keeps
    /// watching until the person touches or scrolls it, or it is covered (`stopWatching`): the system collapses its bar
    /// by itself on a push from a screen with a shorter large title (phone check F6), which `arrive` prevents; this
    /// catches a collapse it didn't, after the push: a safety net for a push with no transition coordinator or a pull
    /// that didn't take (no case seen since E9, plan E9 row). After that, a collapse is the person's scroll up, and
    /// stays.
    private mutating func expand(_ insets: HeaderInsets, inset: CGFloat) -> HeaderScroll? {
        if phase == .arriving { return arrive(insets, inset: inset) }
        if phase == .watching {
            guard !insets.hasScrolled else {
                phase = .settled
                return nil
            }
            return insets.hasCollapsedTheLargeTitle ? insets.largest.map { .scrollView(offset: -$0) } : nil
        }
        phase = .settled
        guard insets.isCollapsed, let largest = insets.largest else { return nil }
        return .scrollView(offset: -largest)
    }
}
