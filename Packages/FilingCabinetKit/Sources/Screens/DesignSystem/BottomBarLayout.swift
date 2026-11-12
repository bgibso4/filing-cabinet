import SwiftUI

/// A screen's scrolling content with a bar of buttons at the bottom centre (Scan, Empty Trash). The bar floats over the
/// content at every text size, and the content fades into the page background before it (#83), so what scrolls under
/// the buttons doesn't crowd them (Ben, 2026-11-11). It is an overlay, not a safe-area inset: an inset's bar sits outside
/// the screen's own view, where the screen's `accessibilityHidden` doesn't reach it and the accessibility audit can't
/// resolve glass buttons (#59). The content's end is lifted by the bar's measured height, so the last row scrolls clear
/// of it.
struct BottomBarLayout<Content: View, Bar: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    // Home.dc.html line 191 (also Collection.dc.html line 125, Trash.dc.html line 118): the fade is 128 pt from the
    // screen's bottom edge, solid page background for its lower 38%, then clear.
    private static var fadeHeight: CGFloat { 128 }
    private static var fadeSolidFraction: CGFloat { 0.38 }

    @State private var barHeight: CGFloat = 0

    var body: some View {
        content
            .safeAreaPadding(.bottom, barHeight)
            .mask { fadeMask }
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

    /// The content's mask: whole down to the fade, then from whole to clear, so the page background shows through. A
    /// mask rather than a gradient view over the content: a view there joins the accessibility tree as an element with
    /// no description, `accessibilityHidden` or not (the iOS 27 audit, 2026-11-11; as with Scan under the capture
    /// layer, #80).
    private var fadeMask: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .clear, location: 1 - Self.fadeSolidFraction),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.fadeHeight)
        }
        .ignoresSafeArea()
    }
}
