import SwiftUI

/// The row of small pages inside a page strip's bar: it hugs a few pages, and for many it stops at the width it is
/// given and keeps the current page in its middle (#119). It follows the pager rather than being scrolled directly.
struct PageStripRow<Page: View>: View {
    let pageCount: Int
    let currentPage: Int
    let gap: CGFloat
    @ViewBuilder let page: (Int) -> Page

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: gap) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        page(index)
                            .pageStripTile(isCurrent: index == currentPage)
                            .id(index)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(true)
            // A few pages sit in the middle of the bar; a 20-page scan runs past its ends.
            .defaultScrollAnchor(.center, for: .alignment)
            // The bar hugs a few pages and stops at the screen's margins for many.
            .frame(maxWidth: PageStripTile.rowWidth(pages: pageCount, gap: gap))
            .frame(height: PageStripTile.currentSize.height)
            .onChange(of: currentPage, initial: true) { _, page in
                proxy.scrollTo(page, anchor: .center)
            }
        }
    }
}
