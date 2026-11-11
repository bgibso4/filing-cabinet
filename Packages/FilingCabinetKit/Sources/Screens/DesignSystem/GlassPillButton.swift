import SwiftUI

/// A pill of plain Liquid Glass with ink text: a grid's Move to Trash while selecting (B12, A1), between the glass
/// Share and heart circles. Ben chose it over Scan's filled pill there ("I don't really like the dark and white buttons
/// down there"). Disabled, its text turns secondary.
struct GlassPillButton<Label: View>: View {
    let identifier: String
    let action: () -> Void
    @ViewBuilder let label: Label

    // .superpowers/plandoc/p4 A1 (`.gpill`): the pill is 52 pt tall with 22 pt either side of its text; it grows with the
    // text, to 64 pt as Scan's does, and taller only when its text wraps.
    private static var baseHeight: CGFloat { 52 }
    private static var maxHeight: CGFloat { 64 }
    private static var horizontalPadding: CGFloat { 22 }

    @ScaledMetric(relativeTo: .body) private var scaledHeight = Self.baseHeight
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            label
                .font(Tokens.Typography.headline)
                .foregroundStyle(isEnabled ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Self.horizontalPadding)
                .frame(minHeight: min(scaledHeight, Self.maxHeight))
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(.capsule)
                // One element for the whole pill, so the audit measures the text against the pill (as Scan's).
                .accessibilityElement(children: .combine)
        }
        // Not .plain, which fades a disabled pill below AA contrast; the text's own colour says it is off.
        .buttonStyle(UnfadedButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}
