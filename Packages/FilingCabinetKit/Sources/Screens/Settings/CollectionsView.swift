import Core
import ScreenModels
import SwiftUI

/// Settings › Collections (10-02): each collection with how long it keeps scans and how many it holds.
public struct CollectionsView: View {
    private let model: CollectionsModel
    private let onOpen: (BuiltInCollection) -> Void

    // Settings2.dc.html line 51: the list starts 18 pt under the subtitle.
    private static let listTopGap: CGFloat = 18
    // Settings2.dc.html line 54: rows are 60 pt tall.
    private static let rowMinHeight: CGFloat = 60
    // Settings2.dc.html line 55: a 31 pt badge with a 17 pt symbol.
    private static let badgeDiameter: CGFloat = 31
    private static let badgeSymbol: CGFloat = 17
    // Settings2.dc.html line 56: 14 pt after the chevron.
    private static let rowTrailingPadding: CGFloat = 14
    // Settings2.dc.html line 63: the footer is 8 pt under the list.
    private static let footerTopGap: CGFloat = 8

    @Environment(\.dynamicTypeSize) private var typeSize

    private let rest: HeaderRest

    /// `rest` is `.small` in the app; `.large` shows the state a pull reaches.
    public init(model: CollectionsModel, rest: HeaderRest = .small, onOpen: @escaping (BuiltInCollection) -> Void) {
        self.model = model
        self.rest = rest
        self.onOpen = onOpen
    }

    public var body: some View {
        HeaderScrollView(
            title: Text("Collections", bundle: #bundle),
            subtitle: Text(model.subtitle),
            identifier: AccessibilityID.Collections.header,
            rest: rest
        ) {
            VStack(alignment: .leading, spacing: 0) {
                list
                    .padding(.top, Self.listTopGap)
                Text(model.footer)
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .padding(.horizontal, Tokens.Spacing.s4)
                    .padding(.top, Self.footerTopGap)
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.bottom, Tokens.Spacing.s8)
        }
        .background(Tokens.Color.bgGrouped)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.element.collection) { index, row in
                Button {
                    onOpen(row.collection)
                } label: {
                    rowContent(row, showsSeparator: index > 0)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Collections.row(row.collection))
            }
        }
        .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
    }

    /// Badge, name over "Kept 3 months · 23 scans", and a chevron, with the separator inset to the text. At accessibility
    /// sizes the text gets the full width under the badge and chevron, as on Home's rows.
    @ViewBuilder
    private func rowContent(_ row: CollectionsRow, showsSeparator: Bool) -> some View {
        let badge = CollectionBadge(
            collection: row.collection, diameter: Self.badgeDiameter, symbolSize: Self.badgeSymbol)
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
                    HStack(spacing: Tokens.Spacing.s3) {
                        badge
                        Spacer(minLength: 0)
                        DisclosureChevron()
                    }
                    texts(row)
                }
                .padding(.vertical, Tokens.Spacing.s3)
                .padding(.trailing, Self.rowTrailingPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    if showsSeparator { Hairline() }
                }
            } else {
                HStack(spacing: Tokens.Spacing.s3) {
                    badge
                    HStack(spacing: Tokens.Spacing.s2) {
                        texts(row)
                        Spacer(minLength: 0)
                        DisclosureChevron()
                    }
                    .padding(.vertical, Tokens.Spacing.s2)
                    .padding(.trailing, Self.rowTrailingPadding)
                    // Fill the row so the separator sits on its top edge, not at the top of the text.
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        if showsSeparator { Hairline() }
                    }
                }
            }
        }
        .padding(.leading, Tokens.Spacing.s4)
        .frame(minHeight: Self.rowMinHeight)
        .contentShape(.rect)
    }

    private func texts(_ row: CollectionsRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(row.name)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text(row.detail)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }
}
