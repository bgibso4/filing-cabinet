import SwiftUI

/// The Details panel's grabber, whose row always drags the panel (ScanDetails.dc.html line 35).
///
/// A SwiftUI drag rather than `DetailsSwipe`. Seen on iOS 27.0: a `UIGestureRecognizerRepresentable` recognizer isn't
/// created for a touch on a row with no UIKit view, and the touch went to the page's swipe under the panel instead.
/// Revisit if a later iOS creates it there; then the grabber could share `DetailsSwipe` with the body.
struct DetailsGrabber: View {
    /// Off while renaming, where the drag would fight the field's own (Ruling R1).
    let isEnabled: Bool
    let onDrag: (DetailsDrag) -> Void

    // ScanDetails.dc.html line 34: 8 pt above the grabber; line 35: the grabber is 36 by 5 pt.
    private static let topPadding: CGFloat = 8
    private static let width: CGFloat = 36
    private static let height: CGFloat = 5

    /// Whether this drag has reported `.began`. Cleared by its end, or by `isTouching` resetting when a drag is
    /// cancelled, which never reports an end.
    @State private var isTracking = false
    @GestureState private var isTouching = false

    var body: some View {
        Capsule()
            .fill(Tokens.Color.chevron)
            .frame(width: Self.width, height: Self.height)
            .padding(.top, Self.topPadding)
            // The whole row above the body takes the drag, not just the capsule.
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .gesture(drag, isEnabled: isEnabled)
            // A cancelled drag (an interruption, or renaming starting under it) lets the spring go where it was held.
            .onChange(of: isTouching) { _, isTouching in
                if !isTouching && isTracking {
                    isTracking = false
                    onDrag(.ended(velocity: 0))
                }
            }
            .accessibilityHidden(true)
    }

    /// Global coordinates: the panel moves under the finger, so its own space would feed the drag back into itself.
    private var drag: some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($isTouching) { _, isTouching, _ in isTouching = true }
            .onChanged { value in
                if !isTracking {
                    isTracking = true
                    onDrag(.began)
                }
                onDrag(.changed(translation: value.translation.height))
            }
            .onEnded { value in
                isTracking = false
                onDrag(.ended(velocity: value.velocity.height))
            }
    }
}
