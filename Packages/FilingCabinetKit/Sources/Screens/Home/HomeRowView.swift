import Core
import ScreenModels
import SwiftUI

/// One collection row: badge, name, subtitle and chevron, with the separator inset to the text.
struct HomeRowView: View {
    let row: HomeRow
    let showsSeparator: Bool

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
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                if showsSeparator {
                    Tokens.Color.separator.frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.s4)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.collectionRow(row.collection))
    }
}
