import SwiftUI
import UIKit

/// Sets the top offset of the scroll view it sits in, above the top where SwiftUI's `ScrollPosition` stops
/// (`HeaderScroll.scrollView(offset:)`): the system bar follows that offset as it follows a pull, which is the only way
/// to expand a collapsed bar without a gesture. Placed inside a `ScrollView`'s content, so that scroll view is its
/// nearest enclosing `UIScrollView`.
struct ScrollViewOffset: UIViewRepresentable {
    /// An offset to set. `count` tells two asks for the same offset apart, so each one is carried out.
    struct Request: Equatable {
        let offset: CGFloat
        /// Only while a transition (a push, a pop or a modal) brings the screen in, at once, and back to the top when
        /// it ends (`HeaderScroll.pullDuringPush`).
        let duringPush: Bool
        let count: Int
    }

    let request: Request?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let request, request != context.coordinator.done else { return }
        let ancestors = sequence(first: view, next: \.superview).dropFirst()
        guard let scrollView = ancestors.lazy.compactMap({ $0 as? UIScrollView }).first else {
            ScreensLog.logger.error("No scroll view around the header's content to expand the bar in")
            return
        }
        context.coordinator.done = request
        if request.duringPush {
            pull(scrollView, to: request.offset)
        } else {
            // Animated: the bar follows an animated offset all the way, but snapped a jump straight back (simulator,
            // Task 4).
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: request.offset), animated: true)
        }
    }

    /// A jump, the only move that lands before UIKit settles the bar for a transition (an animated one waited for the
    /// transition to end, plan 3, E9). It acts during any transition the controller has, a push, a pop or a modal, not
    /// only a push: the clamp at the end makes that harmless. Outside a transition (Home at launch, a snapshot) nothing
    /// would put the content back, so it is left alone; at the transition's end the content goes back to its top under
    /// the bar, where the scroll view puts it by itself with animations on, but not with them off (UI tests).
    private func pull(_ scrollView: UIScrollView, to offset: CGFloat) {
        let controller = sequence(first: scrollView as UIResponder, next: \.next).lazy
            .compactMap { $0 as? UIViewController }.first
        guard let transition = controller?.transitionCoordinator else { return }
        scrollView.contentOffset.y = offset
        transition.animate(alongsideTransition: nil) { _ in
            let top = -scrollView.adjustedContentInset.top
            if scrollView.contentOffset.y < top { scrollView.contentOffset.y = top }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// The last request carried out.
    final class Coordinator {
        var done: Request?
    }
}
