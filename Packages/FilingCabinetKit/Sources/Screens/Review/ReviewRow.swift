import SwiftUI

/// One of the sheet's two menu rows (Review.dc.html lines 291-307, ScanDetails.dc.html lines 73-97): an icon, a small label over the value, and the
/// up-down chevrons that mark a menu.
struct ReviewRow<Icon: View>: View {
    let label: String
    let value: String
    /// Semibold while the value is a prompt ("Choose a collection").
    var isPrompt = false
    /// Semibold orange: the expiry is soon (07-02).
    var isSoon = false
    @ViewBuilder let icon: Icon

    // Review.dc.html line 291: rows are 60 pt tall at least, with 14 pt between the icon, the text and the chevrons.
    private static var minHeight: CGFloat { 60 }
    private static var gap: CGFloat { 14 }

    @Environment(\.dynamicTypeSize) private var typeSize
    /// Off, the value turns secondary too. The mock fades the whole row to 45% (Review.dc.html line 408), which falls
    /// below AA contrast; secondary text on the well still meets it.
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { stacked } else { inline }
        }
        .padding(.horizontal, Tokens.Spacing.s4)
        .padding(.vertical, Tokens.Spacing.s2)
        .frame(minHeight: Self.minHeight)
        .contentShape(.rect)
    }

    private var inline: some View {
        HStack(spacing: Self.gap) {
            icon
                .accessibilityHidden(true)
            texts
            MenuChevrons()
        }
    }

    /// At accessibility sizes the text gets the full width, so a word never breaks; the icon and chevrons share the
    /// line above, as on Home's rows.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
            HStack {
                icon
                    .accessibilityHidden(true)
                Spacer(minLength: Self.gap)
                MenuChevrons()
            }
            texts
        }
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
            Text(value)
                .font(isPrompt || isSoon ? Tokens.Typography.headline : Tokens.Typography.body)
                .foregroundStyle(valueColor)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueColor: Color {
        if !isEnabled { return Tokens.Color.textSecondary }
        return isSoon ? Tokens.Color.expirySoon : Tokens.Color.textPrimary
    }
}
