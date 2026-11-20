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
        PageStripRow(pageCount: pageCount, currentPage: currentPage, gap: Self.gap) { page in
            ThumbnailView(id: id, page: page, provider: thumbnails)
        }
        .pageStripBar()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .pageStripAdjustable(page: $currentPage, count: pageCount)
        .accessibilityIdentifier(AccessibilityID.Viewer.strip)
    }
}
