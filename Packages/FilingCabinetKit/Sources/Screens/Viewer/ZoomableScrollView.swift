import ScreenModels
import UIKit

/// One page, full screen, fitted into the part of the screen the insets leave, that zooms to full resolution. Zoomed, it
/// grows out to the screen's edges under the controls (see `PageAxisInsets`). At 1× it doesn't scroll at all, so a swipe
/// goes to the pager or the navigation stack.
final class ZoomableScrollView: UIScrollView, UIScrollViewDelegate {
    private static let maximumZoom: CGFloat = 4
    private static let doubleTapZoom: CGFloat = 2

    private let imageView = UIImageView()
    private var image: CGImage?
    private var pageKey: AnyHashable?
    /// The image's size at 1×; the image is only laid out again when this changes.
    private var fittedSize = CGSize.zero

    /// Where 1× fits the page, from the screen's edges. A zoomed page grows into these areas.
    var fitInsets = UIEdgeInsets.zero {
        didSet {
            if fitInsets != oldValue { setNeedsLayout() }
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = Self.maximumZoom
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        decelerationRate = .fast
        isScrollEnabled = false
        // A zoomed page runs under the bar and the strip, which float over it in glass rather than fading it out.
        topEdgeEffect.isHidden = true
        bottomEdgeEffect.isHidden = true
        addSubview(imageView)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Built in code only")
    }

    /// Shows `image`. A different `pageKey` means a different page: it starts at 1×, however the last one was left.
    func show(_ image: CGImage?, pageKey: AnyHashable) {
        if pageKey != self.pageKey {
            self.pageKey = pageKey
            resetZoom()
        }
        guard image !== self.image else { return }
        self.image = image
        imageView.image = image.map { UIImage(cgImage: $0) }
        setNeedsLayout()
    }

    func resetZoom() {
        if zoomScale != 1 { setZoomScale(1, animated: false) }
    }

    /// Double tap: 2× around the point, or back to 1×.
    func toggleZoom(at point: CGPoint, animated: Bool = true) {
        guard zoomScale == 1 else {
            setZoomScale(1, animated: animated)
            return
        }
        let size = CGSize(width: bounds.width / Self.doubleTapZoom, height: bounds.height / Self.doubleTapZoom)
        let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        zoom(to: CGRect(origin: origin, size: size), animated: animated)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = fittedImageSize
        if size != fittedSize {
            fittedSize = size
            zoomScale = 1
            imageView.frame = CGRect(origin: .zero, size: size)
            contentSize = size
        }
        positionContent()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        positionContent()
        // Said aloud by VoiceOver, and how a UI test sees that the page is zoomed.
        accessibilityValue = zoomScale > 1 ? String(localized: "Zoomed", bundle: #bundle) : nil
    }

    private var fittedImageSize: CGSize {
        let region = bounds.inset(by: fitInsets)
        guard let image, image.width > 0, image.height > 0, region.width > 0, region.height > 0 else { return .zero }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(region.width / width, region.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }

    /// Places the page: centred between the controls while it fits there, out to the screen's edges as it grows. At 1×
    /// nothing can scroll, so the offset has to be set here.
    private func positionContent() {
        let across = PageAxisInsets(
            content: contentSize.width, bounds: bounds.width, fitLeading: fitInsets.left, fitTrailing: fitInsets.right)
        let down = PageAxisInsets(
            content: contentSize.height, bounds: bounds.height, fitLeading: fitInsets.top, fitTrailing: fitInsets.bottom
        )
        contentInset = UIEdgeInsets(
            top: down.leading, left: across.leading, bottom: down.trailing, right: across.trailing)
        isScrollEnabled = zoomScale > 1
        if !isScrollEnabled {
            contentOffset = CGPoint(x: -contentInset.left, y: -contentInset.top)
        }
    }

    @objc private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
        toggleZoom(at: recognizer.location(in: imageView))
    }
}
