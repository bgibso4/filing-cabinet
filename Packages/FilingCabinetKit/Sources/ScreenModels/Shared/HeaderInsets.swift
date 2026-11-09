import CoreGraphics

/// The header as the scroll view's top inset shows it (plan 3, E1). The system bar opens with the large title showing and
/// grows the inset by the large title's height, so the first inset is the expanded bar and the drop once it collapses is
/// the large title's height, measured at runtime for any text size.
package struct HeaderInsets: Sendable, Equatable {
    private var expanded: CGFloat?
    private var collapsed: CGFloat?
    private var current: CGFloat = 0

    package init() {}

    /// Takes the scroll view's top inset. Zero (before the bar has laid out) says nothing and is ignored.
    package mutating func record(_ inset: CGFloat) {
        guard inset > 0 else { return }
        current = inset
        guard let expanded else {
            expanded = inset
            return
        }
        if inset < expanded { collapsed = min(collapsed ?? inset, inset) }
    }

    package var hasCollapsed: Bool { collapsed != nil }

    /// Known once the bar has collapsed, so never built with a zero height.
    package var motion: HeaderMotion? {
        guard let expanded, let collapsed else { return nil }
        return HeaderMotion(largeHeight: expanded - collapsed)
    }

    /// How far the large title shows, 0 to 1; before the bar has collapsed, wherever the screen rests.
    package func growth(resting rest: HeaderRest) -> CGFloat {
        guard let motion, let expanded else { return rest == .large ? 1 : 0 }
        return motion.growth(offset: expanded - current)
    }

    /// M8 for a scroll view `height` tall under the status bar. Until the bar has collapsed, all of it: always enough to
    /// collapse it, since the expanded inset includes the large title.
    package func minimumContentHeight(height: CGFloat) -> CGFloat {
        guard let motion, let collapsed else { return height }
        return motion.minimumContentHeight(viewport: height - collapsed)
    }
}
