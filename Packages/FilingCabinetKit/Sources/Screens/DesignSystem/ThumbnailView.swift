import Core
import Library
import SwiftUI

/// One page's thumbnail, filling the frame it is given from the top: what the provider has in memory at once,
/// otherwise the scan-ground colour until the load finishes. Only ever renders the provider's ~400 px thumbnails.
struct ThumbnailView: View {
    let id: ScanID
    let page: Int
    let provider: any ThumbnailProviding
    /// Shows a landscape image whole and centred on the ground instead of cropping it (Collection.dc.html line 209).
    var showsWideImagesWhole = false

    @State private var loaded: CGImage?

    var body: some View {
        let image = provider.cachedThumbnail(for: id, page: page) ?? loaded
        let isWhole = showsWideImagesWhole && (image.map { $0.width > $0.height } ?? false)
        Tokens.Color.scanGround
            .overlay(alignment: isWhole ? .center : .top) {
                if let image {
                    let picture = Image(decorative: image, scale: 1).resizable()
                    if isWhole {
                        picture.scaledToFit()
                    } else {
                        picture.scaledToFill()
                    }
                }
            }
            .clipped()
            .task(id: [AnyHashable(id), AnyHashable(page)]) {
                // A prefetch can have filled the cache since the body last read it; nothing else would redraw this.
                if let cached = provider.cachedThumbnail(for: id, page: page) {
                    loaded = cached
                    return
                }
                let image = await provider.thumbnail(for: id, page: page)
                guard !Task.isCancelled else { return }
                loaded = image
            }
            // A long grid scrolled end to end must not keep every image alive; the provider's cache is the bounded one.
            .onDisappear { loaded = nil }
    }
}
