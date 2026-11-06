import CoreGraphics
import SwiftUI

/// A row of small pages under a multi-page scan, the current one larger (Review.dc.html lines 226-231). The pill
/// already says which page is showing, so the strip is hidden from VoiceOver.
struct PageStrip: View {
    let pages: [CGImage]
    let currentPage: Int

    // Review.dc.html line 227: 4 pt between pages.
    private static let gap: CGFloat = 4

    var body: some View {
        HStack(spacing: Self.gap) {
            ForEach(pages.indices, id: \.self) { index in
                Image(decorative: pages[index], scale: 1)
                    .resizable()
                    .scaledToFill()
                    .pageStripTile(isCurrent: index == currentPage)
            }
        }
        .accessibilityHidden(true)
    }
}
