import SwiftUI
import UIKit

/// A pan that moves Details (#61): on the page it opens Details under the finger, and on the panel's body it drags the
/// panel. It reports `DetailsDrag`'s phases in window points, so the panel moving under the finger never
/// feeds back into the drag.
///
/// It begins only when `begins` accepts the drag so far, and otherwise fails at once, leaving the touch to whatever
/// else wanted it. It never recognizes alongside another gesture: a scroll view's pan under it (the pager, a zoomed
/// page, the panel's body) waits for it to fail first, so a drag `begins` turns down still pages, pans or scrolls. The
/// system's edge swipe back is never a scroll view's pan, and is left alone.
struct DetailsSwipe: UIGestureRecognizerRepresentable {
    /// Whether a drag with this translation so far (points, down positive) moves Details. Asked once, as it would begin.
    let begins: (CGSize) -> Bool
    let onDrag: (DetailsDrag) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.begins = begins
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began:
            onDrag(.began)
            onDrag(.changed(translation: recognizer.translation(in: nil).y))
        case .changed:
            onDrag(.changed(translation: recognizer.translation(in: nil).y))
        case .ended:
            onDrag(.ended(velocity: recognizer.velocity(in: nil).y))
        // An interruption: the spring settles from where the finger left it.
        case .cancelled:
            onDrag(.ended(velocity: 0))
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        fileprivate var begins: (CGSize) -> Bool = { _ in false }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let translation = pan.translation(in: nil)
            return begins(CGSize(width: translation.x, height: translation.y))
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            other is UIPanGestureRecognizer && other.view is UIScrollView
        }
    }
}
