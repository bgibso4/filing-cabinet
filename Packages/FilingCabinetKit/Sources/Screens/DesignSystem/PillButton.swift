import SwiftUI

/// The pill at the bottom centre, in one of two styles. Filled: Liquid Glass tinted graphite in light, near-white in
/// dark (Ben, 2026-11-10; plain glass tried again and turned down 2026-11-11), for Scan. Glass: plain Liquid Glass with ink text, for a grid's Move to Trash while
/// selecting, between the glass Share and heart circles (B12, A1; Ben: "I don't really like the dark and white
/// buttons down there"). Disabled, either turns to plain glass with secondary text.
struct PillButton<Label: View>: View {
    enum Style {
        case filled
        case glass
    }

    let style: Style
    let identifier: String
    let action: () -> Void
    @ViewBuilder let label: Label

    // Home.dc.html lines 205 and 314-315 draw Scan 52 pt tall, 64 pt at the large-text variant, never growing past that
    // (taller only when its text wraps); Ben asked for it 4 pt bigger on his phone (2026-11-11): 56 and 68. The A1 pill
    // stays 52 and 64 (.superpowers/plandoc/p4/index.html line 59).
    private static var filledHeight: CGFloat { 56 }
    private static var filledMaxHeight: CGFloat { 68 }
    private static var glassHeight: CGFloat { 52 }
    private static var glassMaxHeight: CGFloat { 64 }
    // Home.dc.html line 205: Scan's text is 30 pt in from either end; 33 at Ben's bigger size.
    private static var filledPadding: CGFloat { 33 }
    // .superpowers/plandoc/p4/index.html line 60: A1's pill text is 22 pt in from either end.
    private static var glassPadding: CGFloat { 22 }

    /// The text size's scale for the pill's height.
    @ScaledMetric(relativeTo: .body) private var heightScale: CGFloat = 1
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            label
                // Headline (17 pt) for both: A1 draws its pill text at 19 pt; headline is the nearest token.
                .font(Tokens.Typography.headline)
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, style == .filled ? Self.filledPadding : Self.glassPadding)
                .frame(minHeight: minHeight)
                .glassEffect(glass, in: .capsule)
                .contentShape(.capsule)
                // One element for the whole pill, so the audit measures the text against the pill and not against a
                // frame that is exactly the glyphs.
                .accessibilityElement(children: .combine)
        }
        // Not .plain, which fades a disabled pill below AA contrast and lets the content behind it show through.
        .buttonStyle(UnfadedButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private var minHeight: CGFloat {
        style == .filled
            ? min(Self.filledHeight * heightScale, Self.filledMaxHeight)
            : min(Self.glassHeight * heightScale, Self.glassMaxHeight)
    }

    private var ink: Color {
        guard isEnabled else { return Tokens.Color.textSecondary }
        return style == .filled ? Tokens.Color.bgGrouped : Tokens.Color.textPrimary
    }

    private var glass: Glass {
        guard isEnabled else { return .regular }
        return style == .filled ? .regular.tint(Tokens.Color.tint).interactive() : .regular.interactive()
    }
}
