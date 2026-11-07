import Core
import Library
import SwiftUI

/// The small pages under a multi-page scan, the current one larger and in view. It follows the pager rather than being
/// used directly, and only ever renders thumbnails. VoiceOver reads it as "Page 2 of 3".
struct ViewerPageStrip: View {
    let id: ScanID
    let pageCount: Int
    let currentPage: Int
    let label: String
    let thumbnails: any ThumbnailProviding

    // ScanView.dc.html line 254: 3 pt between pages.
    private static let gap: CGFloat = 3

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: Self.gap) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        ThumbnailView(id: id, page: page, provider: thumbnails)
                            .pageStripTile(isCurrent: page == currentPage)
                            .id(page)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(true)
            // A few pages sit in the middle of the screen; a 20-page scan runs past its edges.
            .defaultScrollAnchor(.center, for: .alignment)
            .frame(height: PageStripTile.currentSize.height)
            .onChange(of: currentPage, initial: true) { _, page in
                proxy.scrollTo(page, anchor: .center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier(AccessibilityID.Viewer.strip)
    }
}
