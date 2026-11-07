import Core
import ScreenModels
import SwiftUI

/// One collection row: badge, name, then a subtitle (first launch) or a count, and a chevron, with the separator
/// inset to the text.
struct HomeRowView: View {
    let row: HomeRow
    let showsSeparator: Bool
    let onOpen: () -> Void

    // Home.dc.html line 324: rows are 60 pt (64 pt only in the large-text variant, where Dynamic Type grows them).
    private static let minHeight: CGFloat = 60
    // Home.dc.html line 367: 10 pt above and below the text on first launch, none once counts replace the subtitle.
    private static let subtitlePadding: CGFloat = 10

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.flightDestination) private var flightDestination

    var body: some View {
        Button(action: onOpen) {
            Group {
                if typeSize.isAccessibilitySize { stacked } else { inline }
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .frame(minHeight: Self.minHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Home.collectionRow(row.collection))
    }

    /// Badge, text, count and chevron on one line, with the separator inset to the text.
    private var inline: some View {
        HStack(spacing: Tokens.Spacing.s3) {
            badge
            HStack(spacing: Tokens.Spacing.s3) {
                texts
                Spacer(minLength: 0)
                trailing
            }
            .padding(.vertical, verticalPadding)
            // Fill the row so the separator sits on its top edge, not at the top of the text.
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) { separator }
        }
    }

    /// At accessibility sizes the name and subtitle get the full width, so a name never breaks mid-word. The badge,
    /// count and chevron share the line above, and the separator spans the row.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
            HStack(spacing: Tokens.Spacing.s3) {
                badge
                Spacer(minLength: 0)
                trailing
            }
            texts
        }
        .padding(.vertical, Tokens.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { separator }
    }

    private var badge: some View {
        CollectionBadge(collection: row.collection).flightTarget(.badge(row.collection))
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(row.name)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
            if case .subtitle(let subtitle) = row.detail {
                Text(subtitle)
                    .font(Tokens.Typography.subheadline)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let count = row.shownCount(during: flightDestination) {
            HomeCount(count: count)
        }
        Image(systemName: "chevron.right")
            .font(Tokens.Typography.footnote.weight(.semibold))
            .foregroundStyle(Tokens.Color.chevron)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var separator: some View {
        if showsSeparator { Hairline() }
    }

    private var verticalPadding: CGFloat {
        if case .subtitle = row.detail { Self.subtitlePadding } else { 0 }
    }
}
