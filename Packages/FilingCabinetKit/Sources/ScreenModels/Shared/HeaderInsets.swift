import CoreGraphics

/// The header as the scroll view's top inset shows it (plan 3, E1, E9). The system bar grows the inset by the large
/// title's height as the title shows, so the largest inset seen stands for the expanded bar, the smallest the collapsed
/// one, and their difference is the large title's height, measured at runtime for any text size. The order they arrive
/// in doesn't matter: a screen can appear under a bar that is already collapsed.
package struct HeaderInsets: Sendable, Equatable {
    private var expanded: CGFloat?
    private var collapsed: CGFloat?
    private var current: CGFloat = 0
    /// The large title's line height at the current text size (`HeaderAppearance`), 0 until known.
    package var largeTitleHeight: CGFloat = 0
    /// True once the content has been seen at its top under a laid-out bar.
    private var hasRested = false
    /// True once the content has left its top after resting there: the person has scrolled.
    package private(set) var hasScrolled = false

    /// How far the content may sit past minus the inset and still count as at its top (rounding in the reports).
    private static let topTolerance: CGFloat = 0.5

    package init() {}

    /// True with the content at its top under the bar, or pulled past it (measured: while the bar collapses, the content
    /// runs ahead of the inset).
    package static func isAtTop(inset: CGFloat, contentOffset: CGFloat) -> Bool {
        contentOffset + inset <= topTolerance
    }

    /// Takes the scroll view's top inset, and whether the content is at its top (`isAtTop`). Zero (before the bar has
    /// laid out) says nothing and is ignored.
    package mutating func record(_ inset: CGFloat, atTop isAtTop: Bool = false) {
        guard inset > 0 else { return }
        if !hasScrolled {
            if isAtTop { hasRested = true } else { hasScrolled = hasRested }
        }
        current = inset
        expanded = max(expanded ?? inset, inset)
        collapsed = min(collapsed ?? inset, inset)
    }

    /// The largest inset seen so far.
    package var largest: CGFloat? { expanded }

    /// True when the bar has been seen both ways and is collapsed now.
    package var isCollapsed: Bool { motion != nil && current == collapsed }

    /// True when the bar is collapsed now by more than half the measured large title, the point past which UIKit's own
    /// snap collapses it (B6): a real collapse, not the bar laying out again a few points shorter. False until the
    /// large title's height is known.
    package var hasCollapsedTheLargeTitle: Bool {
        guard isCollapsed, largeTitleHeight > 0, let expanded else { return false }
        return expanded - current > largeTitleHeight / 2
    }

    /// Known once the bar has been seen both ways, so never built with a zero height.
    package var motion: HeaderMotion? {
        guard let expanded, let collapsed, expanded > collapsed else { return nil }
        return HeaderMotion(largeHeight: expanded - collapsed)
    }

    /// M8 for a scroll view `height` tall under the status bar. Until the bar has been seen both ways, all of it:
    /// always enough to collapse it, since the expanded inset includes the large title.
    package func minimumContentHeight(height: CGFloat) -> CGFloat {
        guard let motion, let collapsed else { return height }
        return motion.minimumContentHeight(viewport: height - collapsed)
    }
}
