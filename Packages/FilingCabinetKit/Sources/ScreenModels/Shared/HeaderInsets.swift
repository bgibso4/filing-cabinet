import CoreGraphics

/// The header as the scroll view's top inset shows it (plan 3, E1). The system bar grows the inset by the large title's
/// height as the title shows, so the largest inset seen is the expanded bar, the smallest the collapsed one, and their
/// difference is the large title's height, measured at runtime for any text size. The order they arrive in doesn't
/// matter: a screen can appear under a bar that is already collapsed.
package struct HeaderInsets: Sendable, Equatable {
    private var expanded: CGFloat?
    private var collapsed: CGFloat?
    private var current: CGFloat = 0

    package init() {}

    /// Takes the scroll view's top inset. Zero (before the bar has laid out) says nothing and is ignored.
    package mutating func record(_ inset: CGFloat) {
        guard inset > 0 else { return }
        current = inset
        expanded = max(expanded ?? inset, inset)
        collapsed = min(collapsed ?? inset, inset)
    }

    /// The largest inset seen so far.
    package var largest: CGFloat? { expanded }

    /// True when the bar has been seen both ways and is collapsed now.
    package var isCollapsed: Bool { motion != nil && current == collapsed }

    /// Known once the bar has been seen both ways, so never built with a zero height.
    package var motion: HeaderMotion? {
        guard let expanded, let collapsed, expanded > collapsed else { return nil }
        return HeaderMotion(largeHeight: expanded - collapsed)
    }

    /// How far the large title shows, 0 to 1; until the bar has been seen both ways, wherever the screen rests.
    package func growth(resting rest: HeaderRest) -> CGFloat {
        guard let motion, let expanded else { return rest == .large ? 1 : 0 }
        return motion.growth(offset: expanded - current)
    }

    /// M8 for a scroll view `height` tall under the status bar. Until the bar has been seen both ways, all of it:
    /// always enough to collapse it, since the expanded inset includes the large title.
    package func minimumContentHeight(height: CGFloat) -> CGFloat {
        guard let motion, let collapsed else { return height }
        return motion.minimumContentHeight(viewport: height - collapsed)
    }
}
