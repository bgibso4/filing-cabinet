import Core
import ScreenModels
import SwiftUI

/// One collection row: badge, name, subtitle and chevron, with the separator inset to the text.
struct HomeRowView: View {
    let row: HomeRow
    let showsSeparator: Bool

    // Home.dc.html, first-launch rows: 60 pt minimum height, 10 pt above and below the text, hairline separator.
    private static let minHeight: CGFloat = 60
    private static let verticalPadding: CGFloat = 10
    private static let hairline: CGFloat = 0.5

    var body: some View {
        HStack(spacing: Tokens.Spacing.s3) {
            CollectionBadge(collection: row.collection)
            HStack(spacing: Tokens.Spacing.s3) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.name)
                        .font(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Text(row.subtitle)
                        .font(Tokens.Typography.subheadline)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Tokens.Typography.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.Color.chevron)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Self.verticalPadding)
            .overlay(alignment: .top) {
                if showsSeparator {
                    Tokens.Color.separator.frame(height: Self.hairline)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.s4)
        .frame(minHeight: Self.minHeight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.collectionRow(row.collection))
    }
}
