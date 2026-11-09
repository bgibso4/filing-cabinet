import CoreGraphics

/// The viewer's Details motion as pure functions of one progress value, 0 (closed) to 1 (open). The panel's
/// offset, the page's fit and the chrome's opacity all follow it, so they can never disagree.
package enum DetailsMotion {
    /// A flick of this many progress per second or more decides the target whatever the position (M5).
    private static let flickVelocity: CGFloat = 0.6

    private static func clamped(_ progress: CGFloat) -> CGFloat {
        min(max(progress, 0), 1)
    }

    /// The page's fit bottom, linear between its closed and open values.
    package static func pageFitBottom(progress: CGFloat, closed: CGFloat, open: CGFloat) -> CGFloat {
        closed + (open - closed) * clamped(progress)
    }

    /// The header pill, strip and bottom bar fade out as Details rises (B2).
    package static func chromeOpacity(progress: CGFloat) -> CGFloat {
        1 - clamped(progress)
    }

    /// How far below its open position the panel sits.
    package static func panelOffset(progress: CGFloat, travel: CGFloat) -> CGFloat {
        (1 - progress) * travel
    }

    /// Progress during a drag: an upward (negative) translation raises it.
    package static func progress(dragStart: CGFloat, translation: CGFloat, travel: CGFloat) -> CGFloat {
        clamped(dragStart - translation / travel)
    }

    /// Where a released drag settles: a flick decides, otherwise the halfway point does.
    /// `velocity` is progress per second, positive toward open.
    package static func target(progress: CGFloat, velocity: CGFloat) -> CGFloat {
        if velocity >= flickVelocity { return 1 }
        if velocity <= -flickVelocity { return 0 }
        return progress >= 0.5 ? 1 : 0
    }

    /// Whether a drag on the page opens Details: a mostly vertical upward drag on a page at rest, never in
    /// Trash, where a scan is read-only.
    package static func swipeOpens(translation: CGSize, isPageZoomed: Bool, isFromTrash: Bool) -> Bool {
        !isPageZoomed && !isFromTrash && translation.height < 0
            && abs(translation.height) > abs(translation.width)
    }
}
