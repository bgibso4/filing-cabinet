import SwiftUI

/// A screen's scrolling content with a bar of buttons at the bottom centre (Scan, Empty Trash). The bar floats over the
/// content at every text size, with no fade: its Liquid Glass shows what scrolls under it (Ben, 2026-11-10). It is an
/// overlay, not a safe-area inset: an inset's bar sits outside the screen's own view, where the screen's
/// `accessibilityHidden` doesn't reach it and the accessibility audit can't resolve glass buttons (#59). The content's
/// end is lifted by the bar's measured height, so the last row scrolls clear of it.
struct BottomBarLayout<Content: View, Bar: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    @State private var barHeight: CGFloat = 0

    var body: some View {
        content
            .safeAreaPadding(.bottom, barHeight)
            .overlay(alignment: .bottom) {
                bar
                    .padding(.top, Tokens.Spacing.s4)
                    .frame(maxWidth: .infinity)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        barHeight = $0
                    }
            }
            .background(Tokens.Color.bgGrouped)
    }
}
