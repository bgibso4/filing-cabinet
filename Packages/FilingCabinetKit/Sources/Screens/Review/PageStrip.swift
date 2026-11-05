import CoreGraphics
import SwiftUI

/// A row of small pages under a multi-page scan, the current one larger (Review.dc.html lines 226-231). The pill
/// already says which page is showing, so the strip is hidden from VoiceOver.
struct PageStrip: View {
    let pages: [CGImage]
    let currentPage: Int

    // Review.dc.html line 399: the current page is 34 by 44 pt with 6 pt either side; the others are 26 by 36 pt.
    private static let currentSize = CGSize(width: 34, height: 44)
    private static let otherSize = CGSize(width: 26, height: 36)
    private static let currentMargin: CGFloat = 6
    // Review.dc.html line 227: 4 pt between pages.
    private static let gap: CGFloat = 4

    var body: some View {
        HStack(spacing: Self.gap) {
            ForEach(pages.indices, id: \.self) { index in
                let isCurrent = index == currentPage
                let size = isCurrent ? Self.currentSize : Self.otherSize
                Image(decorative: pages[index], scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
                    .padding(.horizontal, isCurrent ? Self.currentMargin : 0)
            }
        }
        .accessibilityHidden(true)
    }
}
