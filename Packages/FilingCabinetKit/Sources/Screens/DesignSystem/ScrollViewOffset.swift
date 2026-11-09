import SwiftUI
import UIKit

/// Sets the top offset of the scroll view it sits in, above the top where SwiftUI's `ScrollPosition` stops
/// (`HeaderScroll.offset`): the system bar follows that offset as it follows a pull, which is the only way to expand a
/// collapsed bar without a gesture. Placed inside a `ScrollView`'s content, so that scroll view is its nearest
/// enclosing `UIScrollView`.
struct ScrollViewOffset: UIViewRepresentable {
    /// An offset to set. `count` tells two asks for the same offset apart, so each one is carried out.
    struct Request: Equatable {
        let offset: CGFloat
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
        // Animated: the bar follows an animated offset all the way, but snapped a jump straight back (simulator, Task 4).
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: request.offset), animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// The last request carried out.
    final class Coordinator {
        var done: Request?
    }
}
