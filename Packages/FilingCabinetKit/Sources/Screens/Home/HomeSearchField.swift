import Core
import SwiftUI

/// Home's search field under the title (02-01): drawn, not a text field. Tapping it opens Search, which has the real
/// field (M14, E1). It scrolls with Home's content.
struct HomeSearchField: View {
    let onOpen: () -> Void

    // Home.dc.html line 30: the field is at least 44 pt, 8 pt under what is above it, 16 pt in, its glyph 8 pt from
    // "Search".
    private static let minHeight = Tokens.Spacing.tapMin
    private static let topGap = Tokens.Spacing.s2

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Tokens.Spacing.s2) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                Text("Search", bundle: #bundle)
                Spacer(minLength: 0)
            }
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textSecondary)
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.vertical, Tokens.Spacing.s2)
            .frame(minHeight: Self.minHeight)
            .background(Tokens.Color.bgSurface, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Home.search)
        .padding(.top, Self.topGap)
    }
}
