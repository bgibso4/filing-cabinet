import SwiftUI

/// A round icon in Liquid Glass: the face of `GlassCircleButton`, and of a control that isn't a plain button (Share's
/// `ShareLink`). The glyph follows Dynamic Type and the circle grows with it; at default sizes it is `diameter`.
struct GlassCircleLabel: View {
    let systemImage: String
    /// A token text style, so the glyph scales with Dynamic Type.
    let font: Font
    let diameter: CGFloat

    var body: some View {
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
}
