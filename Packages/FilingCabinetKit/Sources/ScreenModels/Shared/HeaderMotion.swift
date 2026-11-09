import CoreGraphics

/// The header's maths. Offsets are measured from the fully expanded position:
/// 0 means the large title fully shows, `largeHeight` means it has collapsed.
package struct HeaderMotion: Sendable, Equatable {
    package let largeHeight: CGFloat

    package init(largeHeight: CGFloat) {
        self.largeHeight = largeHeight
    }

    /// 1 at or above 0, 0 at or past `largeHeight`, linear between.
    package func growth(offset: CGFloat) -> CGFloat {
        min(max(1 - offset / largeHeight, 0), 1)
    }

    /// The small title and subtitle in the bar fade in as the large title collapses.
    package static func smallTitleOpacity(growth: CGFloat) -> CGFloat {
        1 - growth
    }

    /// The large title shows as far as it has grown, so a screen resting small never draws it: the bar shows the large
    /// title slot of the screen it is leaving while a pop runs, over the large title of the screen it goes back to.
    package static func largeTitleOpacity(growth: CGFloat) -> CGFloat {
        growth
    }

    /// Content at least this tall can always scroll the large title away, however short it is.
    package func minimumContentHeight(viewport: CGFloat) -> CGFloat {
        viewport + largeHeight
    }
}
