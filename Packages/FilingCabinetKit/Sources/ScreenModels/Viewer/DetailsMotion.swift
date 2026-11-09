import CoreGraphics

/// The viewer's Details motion as pure functions of one progress value, 0 (closed) to 1 (open). The panel's
/// offset, the page's fit and the chrome's opacity all follow it, so they can never disagree.
package nonisolated enum DetailsMotion {
    /// A flick of this many progress per second or more decides the target whatever the position (M5).
    private static let flickVelocity: CGFloat = 0.6
    /// A body scrolled less than this from its top is at its top: scroll offsets land on fractions of a point.
    private static let bodyTopTolerance: CGFloat = 0.5

    private static func clamped(_ progress: CGFloat) -> CGFloat {
        min(max(progress, 0), 1)
    }

    /// The panel's travel from fully up to fully below the screen: its height and the inset below it. Unknown (0) until
    /// the panel has been measured, so nothing moves against a panel of no height.
    package static func travel(panelHeight: CGFloat, inset: CGFloat) -> CGFloat {
        panelHeight > 0 ? panelHeight + inset : 0
    }

    /// The page's fit bottom, linear between its closed value and `gap` above the open panel. While the travel is
    /// unknown the page keeps its closed fit.
    package static func pageFitBottom(progress: CGFloat, closed: CGFloat, travel: CGFloat, gap: CGFloat) -> CGFloat {
        guard travel > 0 else { return closed }
        return closed + (travel + gap - closed) * clamped(progress)
    }

    /// The header pill, strip and bottom bar fade out as Details rises (B2).
    package static func chromeOpacity(progress: CGFloat) -> CGFloat {
        1 - clamped(progress)
    }

    /// The chrome stops taking taps once Details is past halfway.
    package static func chromeTakesTaps(progress: CGFloat) -> Bool {
        progress <= 0.5
    }

    /// The chrome leaves VoiceOver, and the pill the bar, once Details is fully up and the chrome invisible.
    package static func chromeIsHidden(progress: CGFloat) -> Bool {
        progress >= 1
    }

    /// The room a piece of chrome keeps in the layout as it fades: at large text the pill sits below the bar, and gives
    /// its room up to the page as Details rises.
    package static func chromeRoom(progress: CGFloat, height: CGFloat) -> CGFloat {
        height * chromeOpacity(progress: progress)
    }

    /// How far below its open position the panel sits.
    package static func panelOffset(progress: CGFloat, travel: CGFloat) -> CGFloat {
        (1 - progress) * travel
    }

    /// Progress during a drag: an upward (negative) translation raises it. Until the panel is measured there is no
    /// travel, and progress stays where the drag started.
    package static func progress(dragStart: CGFloat, translation: CGFloat, travel: CGFloat) -> CGFloat {
        guard travel > 0 else { return clamped(dragStart) }
        return clamped(dragStart - translation / travel)
    }

    /// A drag's vertical speed in points per second (downward positive, as UIKit reports it) as progress per second,
    /// positive toward open. Zero until the panel is measured.
    package static func progressVelocity(pointsPerSecond: CGFloat, travel: CGFloat) -> CGFloat {
        guard travel > 0 else { return 0 }
        return -pointsPerSecond / travel
    }

    /// The progress the page's fit takes: under Reduce Motion it jumps to where the spring is going (B11).
    package static func layoutProgress(position: CGFloat, target: CGFloat, reducesMotion: Bool) -> CGFloat {
        reducesMotion ? target : position
    }

    /// The progress the panel's offset takes. Under Reduce Motion it doesn't slide (B11): it jumps up to open, and on
    /// the way down holds where it was when the close began (`origin`) while it fades out.
    package static func panelProgress(
        position: CGFloat, target: CGFloat, origin: CGFloat, reducesMotion: Bool
    ) -> CGFloat {
        guard reducesMotion else { return position }
        return target > 0 ? target : origin
    }

    /// The panel fades in and out with the spring under Reduce Motion, and is opaque otherwise (B11).
    package static func panelOpacity(progress: CGFloat, reducesMotion: Bool) -> CGFloat {
        reducesMotion ? clamped(progress) : 1
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

    /// Whether a drag on the panel's body moves the panel rather than scrolling the body, as Apple's sheets do: only a
    /// mostly downward drag, and only with the body at its top.
    package static func bodyDragMovesPanel(translation: CGSize, isBodyAtTop: Bool) -> Bool {
        isBodyAtTop && translation.height > 0 && abs(translation.height) > abs(translation.width)
    }

    /// Whether the panel's body is at its top, from how far it is scrolled from there (negative while pulled past it).
    package static func bodyIsAtTop(scrolled: CGFloat) -> Bool {
        scrolled < bodyTopTolerance
    }
}
