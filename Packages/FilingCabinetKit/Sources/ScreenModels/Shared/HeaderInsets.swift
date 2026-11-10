import CoreGraphics

/// The header as the scroll view's top inset shows it (plan 3, E1). The system bar grows the inset by the large title's
/// height as the title shows, so the largest inset seen stands for the expanded bar, the smallest the collapsed one, and
/// their difference is the large title's height, measured at runtime for any text size. The order they arrive in doesn't
/// matter: a screen can appear under a bar that is already collapsed. The largest can overshoot the expanded bar: the bar
/// first lays out taller (168 pt on Home, then 156.67 pt; see `record`), which is why a screen resting large measures
/// from the inset it rested under instead.
///
/// A screen resting large (Home) opens expanded and has never seen the bar collapsed when it first scrolls, so the
/// large title's own measured height stands in for the inset drop, measured from the bar it rested under: the small
/// title fades in on the first scroll instead of showing at once.
package struct HeaderInsets: Sendable, Equatable {
    private var expanded: CGFloat?
    private var collapsed: CGFloat?
    private var current: CGFloat = 0
    private var largeTitle: CGFloat = 0
    /// The inset last seen with the content at its top before it first scrolled: the expanded bar a screen rests under.
    private var resting: CGFloat?
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
    /// laid out) says nothing and is ignored. Until the content first scrolls, the latest inset at its top is the bar
    /// the screen rests under: the bar first lays out taller, with the system's own large title (168 pt on Home, then
    /// 156.67 pt). Later, the content can reach its top under a collapsed bar, which a pull then expands.
    package mutating func record(_ inset: CGFloat, atTop isAtTop: Bool = false) {
        guard inset > 0 else { return }
        if !hasScrolled {
            if isAtTop { resting = inset } else { hasScrolled = resting != nil }
        }
        current = inset
        expanded = max(expanded ?? inset, inset)
        collapsed = min(collapsed ?? inset, inset)
    }

    /// Takes the large title's height as drawn. It shrinks with the bar as it collapses, so the tallest counts.
    package mutating func recordLargeTitle(height: CGFloat) {
        largeTitle = max(largeTitle, height)
    }

    /// The largest inset seen so far.
    package var largest: CGFloat? { expanded }

    /// True when the bar has been seen both ways and is collapsed now.
    package var isCollapsed: Bool { motion != nil && current == collapsed }

    /// True when the bar is collapsed now by more than half the measured large title, the point past which UIKit's own
    /// snap collapses it (B6): a real collapse, not the bar laying out again a few points shorter (Home's first 168 pt,
    /// then 164.67 pt). False until the large title has been measured.
    package var hasCollapsedTheLargeTitle: Bool {
        guard isCollapsed, largeTitle > 0, let expanded else { return false }
        return expanded - current > largeTitle / 2
    }

    /// Known once the bar has been seen both ways, so never built with a zero height.
    package var motion: HeaderMotion? {
        guard let expanded, let collapsed, expanded > collapsed else { return nil }
        return HeaderMotion(largeHeight: expanded - collapsed)
    }

    /// How far the large title shows, 0 to 1. Resting large, from the measured title under the bar the screen rested
    /// under: the insets' drop would read the first partial scroll as the whole title. Otherwise from the insets once the
    /// bar has been seen both ways; until then, wherever the screen rests.
    package func growth(resting rest: HeaderRest) -> CGFloat {
        if rest == .large, largeTitle > 0, let resting {
            return HeaderMotion(largeHeight: largeTitle).growth(offset: resting - current)
        }
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
