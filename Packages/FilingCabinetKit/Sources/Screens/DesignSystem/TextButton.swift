import SwiftUI

/// A plain text button under a `CapsuleButton`: the second, quieter choice (the failure screen's Try again, the
/// welcome's Not now). Body text in the primary colour, at least 44 pt tall.
struct TextButton<Label: View>: View {
    let identifier: String
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Spacing.s6)
                .frame(minHeight: Tokens.Spacing.tapMin)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
