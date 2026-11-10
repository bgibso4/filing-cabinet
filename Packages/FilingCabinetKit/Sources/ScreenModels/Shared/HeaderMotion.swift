import CoreGraphics

/// The header's maths, from the large title's height (the bar's inset drop as it collapses).
package struct HeaderMotion: Sendable, Equatable {
    package let largeHeight: CGFloat

    package init(largeHeight: CGFloat) {
        self.largeHeight = largeHeight
    }

    /// Content at least this tall can always scroll the large title away, however short it is.
    package func minimumContentHeight(viewport: CGFloat) -> CGFloat {
        viewport + largeHeight
    }
}
