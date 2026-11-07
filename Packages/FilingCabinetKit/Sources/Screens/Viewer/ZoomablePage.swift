import Core
import Library
import SwiftUI

/// One page in the viewer: what the provider has in memory at once, otherwise the load's result when it arrives.
/// It holds a full-size image only while `holdsImage`; the viewer turns that off once the page is far from the current
/// one, and the view stays (see `Pager`) with nothing in it.
struct ZoomablePage: View {
    let id: ScanID
    let index: Int
    let isCurrent: Bool
    let holdsImage: Bool
    let label: String
    let fitInsets: UIEdgeInsets
    let provider: any PageImageProviding

    private struct Key: Hashable {
        // periphery:ignore - read only by the synthesized Hashable and Equatable
        let id: ScanID
        // periphery:ignore - read only by the synthesized Hashable and Equatable
        let index: Int
    }

    private struct Loaded {
        let key: Key
        let image: CGImage
    }

    @State private var loaded: Loaded?

    var body: some View {
        let key = Key(id: id, index: index)
        Representable(
            image: image(for: key),
            pageKey: key,
            isCurrent: isCurrent,
            label: label,
            fitInsets: fitInsets
        )
        .task(id: holdsImage ? key : nil) {
            guard holdsImage else {
                loaded = nil
                return
            }
            // A neighbour's load can have filled the cache since the body last read it; nothing else would redraw this.
            if let cached = provider.cachedPage(for: id, index: index) {
                loaded = Loaded(key: key, image: cached)
                return
            }
            let image = await provider.page(for: id, index: index)
            guard !Task.isCancelled else { return }
            guard let image else {
                ScreensLog.logger.error("Page \(index, privacy: .public) of a scan could not be loaded")
                return
            }
            loaded = Loaded(key: key, image: image)
        }
    }

    private func image(for key: Key) -> CGImage? {
        guard holdsImage else { return nil }
        return provider.cachedPage(for: id, index: index) ?? (loaded?.key == key ? loaded?.image : nil)
    }

    private struct Representable: UIViewRepresentable {
        let image: CGImage?
        let pageKey: Key
        let isCurrent: Bool
        let label: String
        let fitInsets: UIEdgeInsets

        func makeUIView(context: Context) -> ZoomableScrollView {
            let view = ZoomableScrollView()
            view.isAccessibilityElement = true
            view.accessibilityTraits = .image
            view.accessibilityIdentifier = AccessibilityID.Viewer.page
            return view
        }

        func updateUIView(_ view: ZoomableScrollView, context: Context) {
            view.fitInsets = fitInsets
            view.accessibilityLabel = label
            view.show(image, pageKey: pageKey)
            // Coming back to a page finds it whole.
            if !isCurrent { view.resetZoom() }
        }
    }
}
