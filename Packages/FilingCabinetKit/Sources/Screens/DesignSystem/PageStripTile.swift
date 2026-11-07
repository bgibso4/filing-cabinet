import SwiftUI

/// The size every page strip gives a page.
enum PageStripTile {
    // Review.dc.html line 399, ScanView.dc.html line 372: the current page is 34 by 44 pt with 6 pt either side; the
    // others are 26 by 36 pt.
    static let currentSize = CGSize(width: 34, height: 44)
    static let otherSize = CGSize(width: 26, height: 36)
    static let currentMargin: CGFloat = 6
    // No mock (Task 20, P3): the current page is ringed, so it reads over any page in light and dark.
    static let currentRing: CGFloat = 2
    // No mock (Task 20, P3): the strip's glass bar reaches this far around its pages.
    static let barPadding = Tokens.Spacing.s2

    /// The width of a row of `pages` pages with `gap` between them, the current one included.
    static func rowWidth(pages: Int, gap: CGFloat) -> CGFloat {
        guard pages > 0 else { return 0 }
        let others = CGFloat(pages - 1)
        return currentSize.width + 2 * currentMargin + others * otherSize.width + others * gap
    }
}

extension View {
    func pageStripTile(isCurrent: Bool) -> some View {
        let size = isCurrent ? PageStripTile.currentSize : PageStripTile.otherSize
        return
            self
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
            .overlay { PageStripTileEdge(isCurrent: isCurrent) }
            .padding(.horizontal, isCurrent ? PageStripTile.currentMargin : 0)
    }
}

/// A page's edge in the strip: the current one ringed, the others outlined with a hairline so white pages read on pale
/// glass. Pages are paper, white in both appearances, so both lines take the light appearance's colours.
private struct PageStripTileEdge: View {
    let isCurrent: Bool
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.nested)
            .strokeBorder(
                isCurrent ? Tokens.Color.textPrimary : Tokens.Color.separator,
                lineWidth: isCurrent ? PageStripTile.currentRing : 1 / displayScale
            )
            .environment(\.colorScheme, .light)
    }
}

extension View {
    /// Lets VoiceOver page with a swipe up or down on the strip, as the pager does with a finger.
    func pageStripAdjustable(page: Binding<Int>, count: Int) -> some View {
        accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: page.wrappedValue = min(page.wrappedValue + 1, count - 1)
            case .decrement: page.wrappedValue = max(page.wrappedValue - 1, 0)
            @unknown default: break
            }
        }
    }

    /// The Liquid Glass bar a page strip sits on, so its pages read over a white page as well as the background (P3).
    func pageStripBar() -> some View {
        self
            .padding(PageStripTile.barPadding)
            .glassEffect(.regular, in: .capsule)
    }
}
