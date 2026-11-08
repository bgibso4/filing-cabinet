import Core
import SwiftUI

/// One page that zooms full screen, shared by the viewer and review: the image fitted into the part of the screen
/// `fitInsets` leaves, growing out to the screen's edges as it zooms (see `ZoomableScrollView`).
struct ZoomablePageView: UIViewRepresentable {
    let image: CGImage?
    /// Another key is another page: it starts at 1×.
    let pageKey: AnyHashable
    let isCurrent: Bool
    /// What VoiceOver reads for the page; nil when something else names it (review's pill), so the page is decorative.
    let label: String?
    let fitInsets: UIEdgeInsets
    /// Whether the page is zoomed past 1×, each time that changes.
    let onZoomChange: (Bool) -> Void

    func makeUIView(context: Context) -> ZoomableScrollView {
        let view = ZoomableScrollView()
        view.accessibilityTraits = .image
        return view
    }

    func updateUIView(_ view: ZoomableScrollView, context: Context) {
        view.fitInsets = fitInsets
        view.onZoomChange = onZoomChange
        view.accessibilityLabel = label
        // Only the page on screen is in the accessibility tree; VoiceOver pages with the strip's adjustable action, so
        // focus never lands on a page that is off screen. A decorative page never is. Hidden, not just "not an
        // element": a scroll view that isn't an element is still a container, and would carry the identifier.
        let isElement = label != nil && isCurrent
        view.isAccessibilityElement = isElement
        view.accessibilityElementsHidden = !isElement
        view.accessibilityIdentifier = isElement ? AccessibilityID.Viewer.page : nil
        view.show(image, pageKey: pageKey)
        // Coming back to a page finds it whole.
        if !isCurrent { view.resetZoom() }
    }
}
