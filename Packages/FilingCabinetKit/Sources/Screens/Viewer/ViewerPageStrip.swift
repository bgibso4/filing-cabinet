import Core
import Library
import SwiftUI

/// The small pages under a multi-page scan, on a glass bar, the current one larger, ringed and in view. It follows the
/// pager rather than being used directly, and only ever renders thumbnails. VoiceOver reads it as "Page 2 of 3" and pages with it.
struct ViewerPageStrip: View {
    let id: ScanID
    let pageCount: Int
    @Binding var currentPage: Int
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
            // A few pages sit in the middle of the bar; a 20-page scan runs past its ends.
            .defaultScrollAnchor(.center, for: .alignment)
            // The bar hugs a few pages and stops at the screen's margins for many.
            .frame(maxWidth: PageStripTile.rowWidth(pages: pageCount, gap: Self.gap))
            .frame(height: PageStripTile.currentSize.height)
            .onChange(of: currentPage, initial: true) { _, page in
                proxy.scrollTo(page, anchor: .center)
            }
        }
        .pageStripBar()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .pageStripAdjustable(page: $currentPage, count: pageCount)
        .accessibilityIdentifier(AccessibilityID.Viewer.strip)
    }
}
