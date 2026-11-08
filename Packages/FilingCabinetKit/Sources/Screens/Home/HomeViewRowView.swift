import Core
import ScreenModels
import SwiftUI

/// One row of the views card (Recent, All Scans, Trash): neutral badge, name, optional count and a chevron.
struct HomeViewRowView: View {
    let row: HomeViewRow
    let showsSeparator: Bool
    let onOpen: () -> Void

    // Home.dc.html line 324: 60 pt rows.
    private static let minHeight: CGFloat = 60
    // Home.dc.html line 187: the neutral badge matches the collection badges' 34 pt circle, with an 18 pt symbol.
    private static let diameter: CGFloat = 34
    private static let symbolSize: CGFloat = 18

    @Environment(\.dynamicTypeSize) private var typeSize

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
        .accessibilityIdentifier(identifier)
    }

    private var inline: some View {
        HStack(spacing: Tokens.Spacing.s3) {
            badge
            HStack(spacing: Tokens.Spacing.s3) {
                name
                Spacer(minLength: 0)
                trailing
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) { separator }
        }
    }

    /// At accessibility sizes the name gets the full width; the badge, count and chevron share the line above.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
            HStack(spacing: Tokens.Spacing.s3) {
                badge
                Spacer(minLength: 0)
                trailing
            }
            name
        }
        .padding(.vertical, Tokens.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { separator }
    }

    private var name: some View {
        Text(row.name)
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textPrimary)
    }

    @ViewBuilder
    private var trailing: some View {
        if let count = row.count {
            HomeCount(count: count)
        }
        DisclosureChevron()
    }

    @ViewBuilder
    private var separator: some View {
        if showsSeparator { Hairline() }
    }

    private var badge: some View {
        ViewBadge(symbol: symbol, diameter: Self.diameter, symbolSize: Self.symbolSize)
    }

    private var symbol: String {
        switch row.kind {
        case .recent: ViewSymbol.recent
        case .all: ViewSymbol.all
        case .trash: ViewSymbol.trash
        }
    }

    private var identifier: String {
        switch row.kind {
        case .recent: AccessibilityID.Home.recentRow
        case .all: AccessibilityID.Home.allRow
        case .trash: AccessibilityID.Home.trashRow
        }
    }
}
