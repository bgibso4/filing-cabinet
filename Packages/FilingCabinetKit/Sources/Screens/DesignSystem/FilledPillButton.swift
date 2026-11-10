import SwiftUI

/// The filled pill at the bottom centre: Liquid Glass tinted graphite in light, near-white in dark (Ben, 2026-11-10).
/// Scan, and a grid's Move to Trash while selecting, in Scan's place (#68). Disabled, it turns to plain glass with
/// secondary text.
struct FilledPillButton<Label: View>: View {
    let identifier: String
    let action: () -> Void
    @ViewBuilder let label: Label

    // Home.dc.html: the pill is 52 pt tall, 64 pt at the large-text variant, and never grows past that.
    private static var baseHeight: CGFloat { 52 }
    private static var maxHeight: CGFloat { 64 }
    // Home.dc.html: horizontal padding inside the pill.
    private static var horizontalPadding: CGFloat { 30 }

    @ScaledMetric(relativeTo: .body) private var scaledHeight = Self.baseHeight
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            label
                .font(Tokens.Typography.headline)
                .foregroundStyle(isEnabled ? Tokens.Color.bgGrouped : Tokens.Color.textSecondary)
                .padding(.horizontal, Self.horizontalPadding)
                .frame(minHeight: min(scaledHeight, Self.maxHeight))
                .glassEffect(isEnabled ? .regular.tint(Tokens.Color.tint).interactive() : .regular, in: .capsule)
                // One element for the whole pill, so the audit measures the text against the pill and not against a
                // frame that is exactly the glyphs.
                .accessibilityElement(children: .combine)
        }
        // Not .plain, which fades a disabled pill below AA contrast and lets the content behind it show through.
        .buttonStyle(UnfadedButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}
