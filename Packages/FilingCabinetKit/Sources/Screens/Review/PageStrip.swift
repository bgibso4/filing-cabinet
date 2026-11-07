import Core
import CoreGraphics
import SwiftUI

/// A row of small pages under a multi-page scan on a glass bar, the current one larger and ringed (Review.dc.html lines
/// 226-231, the bar as the viewer's). VoiceOver reads it as "Page 2 of 3" and pages with it.
struct PageStrip: View {
    let pages: [CGImage]
    @Binding var currentPage: Int
    let label: String

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
        .pageStripBar()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier(AccessibilityID.Review.strip)
        .pageStripAdjustable(page: $currentPage, count: pages.count)
    }
}
