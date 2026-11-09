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

    package func restingOffset(_ rest: HeaderRest) -> CGFloat {
        switch rest {
        case .small: largeHeight
        case .large: 0
        }
    }

    /// Content at least this tall can always scroll the large title away, however short it is.
    package func minimumContentHeight(viewport: CGFloat) -> CGFloat {
        viewport + largeHeight
    }
}
