import Core
import Library
import ScreenModels
import SwiftUI

/// Search before typing (08-02): "Recently viewed", one row of up to four scans opened lately, then "Recent searches"
/// with Clear. A scan opens the viewer; a search fills the field.
struct SearchBeforeTyping: View {
    let viewed: [SearchViewed]
    let searches: [String]
    let thumbnails: any ThumbnailProviding
    let onOpen: (ScanID) -> Void
    let onSearch: (String) -> Void
    let onClear: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    // Search.dc.html lines 51 and 66 (option D): section headers are at least 44 pt, 6 pt under the filters for
    // Recently viewed and 8 pt under it for Recent searches, 2 pt over what follows.
    private static let headerMinHeight = Tokens.Spacing.tapMin
    private static let viewedTopGap: CGFloat = 6
    private static let searchesTopGap = Tokens.Spacing.s2
    private static let headerBottomGap: CGFloat = 2
    // Search.dc.html lines 52-55: four thumbnails a row, 3 : 4, 8 pt apart, 4 pt over their dot and title, the dot
    // 4 pt from the title.
    private static let viewedColumns = 4
    // My call (no large-text mock): two a row at accessibility sizes.
    private static let largeTextViewedColumns = 2
    private static let viewedAspect: CGFloat = 3 / 4
    private static let viewedGap = Tokens.Spacing.s2
    private static let viewedTitleGap = Tokens.Spacing.s1
    // Search.dc.html line 70: recent searches' rows are at least 44 pt.
    private static let recentMinHeight = Tokens.Spacing.tapMin

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewed.isEmpty { recentlyViewed(viewed) }
            if !searches.isEmpty { recentSearches(searches, below: !viewed.isEmpty) }
        }
    }

    private func header(_ title: Text) -> some View {
        title
            .font(Tokens.Typography.title2)
            .foregroundStyle(Tokens.Color.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    /// 08-02: one row of up to four scans opened lately, each its thumbnail, dot and title.
    private func recentlyViewed(_ viewed: [SearchViewed]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(Text("Recently viewed", bundle: #bundle))
                .frame(minHeight: Self.headerMinHeight)
                .padding(.top, Self.viewedTopGap)
                .padding(.bottom, Self.headerBottomGap)
            LazyVGrid(columns: viewedColumns, alignment: .leading, spacing: Self.viewedGap) {
                ForEach(viewed) { viewedScan($0) }
            }
        }
    }

    /// Four in a row; two at accessibility sizes, so the titles have room to wrap.
    private var viewedColumns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? Self.largeTextViewedColumns : Self.viewedColumns
        return Array(repeating: GridItem(.flexible(), spacing: Self.viewedGap, alignment: .top), count: count)
    }

    private func viewedScan(_ scan: SearchViewed) -> some View {
        Button {
            onOpen(scan.id)
        } label: {
            VStack(alignment: .leading, spacing: Self.viewedTitleGap) {
                Color.clear
                    .aspectRatio(Self.viewedAspect, contentMode: .fit)
                    .overlay { ThumbnailView(id: scan.id, page: 0, provider: thumbnails) }
                    .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
                // At large text the title wraps, and the dot stays with its first line (as the viewer's header).
                HStack(
                    alignment: typeSize.isAccessibilitySize ? .firstTextBaseline : .center, spacing: Tokens.Spacing.s1
                ) {
                    CollectionDot(collection: scan.collection)
                    Text(scan.title)
                        .font(Tokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Color.textPrimary)
                        // Search.dc.html line 56: one line with an ellipsis; above the default size it wraps rather
                        // than cutting off (requirements 06 · Accessibility).
                        .lineLimit(typeSize <= .large ? 1 : nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scan.title)
        .accessibilityIdentifier(AccessibilityID.Search.viewed(scan.id))
    }

    /// 08-02: the last searches, newest first, with Clear. Tapping one fills the field.
    private func recentSearches(_ searches: [String], below: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header(Text("Recent searches", bundle: #bundle))
                Spacer(minLength: Tokens.Spacing.s2)
                Button {
                    onClear()
                } label: {
                    Text("Clear", bundle: #bundle)
                        .font(Tokens.Typography.subheadline)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .frame(minHeight: Self.headerMinHeight)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Search.clear)
            }
            .frame(minHeight: Self.headerMinHeight)
            .padding(.top, below ? Self.searchesTopGap : Self.viewedTopGap)
            .padding(.bottom, Self.headerBottomGap)
            VStack(spacing: 0) {
                ForEach(Array(searches.enumerated()), id: \.offset) { index, search in
                    recentSearch(search, index: index)
                }
            }
            .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
        }
    }

    private func recentSearch(_ search: String, index: Int) -> some View {
        Button {
            onSearch(search)
        } label: {
            HStack(spacing: Tokens.Spacing.s3) {
                Image(systemName: "clock")
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityHidden(true)
                Text(search)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: Self.recentMinHeight, alignment: .leading)
                    .overlay(alignment: .top) {
                        if index > 0 { Hairline() }
                    }
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(search)
        .accessibilityIdentifier(AccessibilityID.Search.recent(index))
    }
}
