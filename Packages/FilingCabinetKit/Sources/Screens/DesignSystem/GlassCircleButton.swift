import SwiftUI

/// A floating round icon button in Liquid Glass, as on Review's top bar. The glyph follows Dynamic Type and the
/// circle grows with it; at default sizes it is `diameter`.
struct GlassCircleButton: View {
    let systemImage: String
    /// A token text style, so the glyph scales with Dynamic Type.
    let font: Font
    let label: Text
    let identifier: String
    // Review.dc.html line 215: the button is 48 pt.
    var diameter: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(font)
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(Tokens.Spacing.s2)
                .frame(minWidth: diameter, minHeight: diameter)
                // Always its full size, so a tight layout can't squash the circle under a large glyph.
                .fixedSize()
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
