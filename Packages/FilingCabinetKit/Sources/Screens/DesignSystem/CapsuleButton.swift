import SwiftUI

/// A full-width opaque pill in the tint colour: the main action of a sheet or full screen (the camera-off sheet's Open
/// Settings, the failure screen's Send report). Opaque, not Liquid Glass, so the accessibility audit measures its text
/// against a solid colour.
struct CapsuleButton<Label: View>: View {
    let identifier: String
    /// The mock's height at default sizes; the pill grows when large text wraps.
    let minHeight: CGFloat
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Color.bgGrouped)
                .multilineTextAlignment(.center)
                // Wraps rather than truncates when the text is large.
                .fixedSize(horizontal: false, vertical: true)
                // Keeps large text off the capsule's ends; at default sizes the pill is wider than the label anyway.
                .padding(.horizontal, Tokens.Spacing.s6)
                .padding(.vertical, Tokens.Spacing.s2)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Tokens.Color.tint, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
