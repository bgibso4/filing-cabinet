import Core
import Library
import ScreenModels
import SwiftUI
import os

/// A collection, Recent or All Scans: a back button, the title, a lazy grid of scans (or the empty state) and Scan.
public struct CollectionGridView: View {
    private let model: CollectionGridModel
    private let thumbnails: any ThumbnailProviding
    private let canScan: Bool
    private let onOpen: (ScanID) -> Void
    private let onScan: () -> Void

    // Collection.dc.html line 25: 10 pt between the icon and the title. The 8 pt above the title is already there: the
    // system bar is 10 pt taller than the mock's 44 pt button.
    private static let iconGap: CGFloat = 10
    // Collection.dc.html line 26: 34 pt badge with a 19 pt symbol. LargeText.dc.html line 23: 44 and 24 at large text.
    private static let badgeDiameter: CGFloat = 34
    private static let badgeSymbol: CGFloat = 19
    private static let largeBadgeDiameter: CGFloat = 44
    private static let largeBadgeSymbol: CGFloat = 24
    // Collection.dc.html line 27: the views' bare symbol is 26 pt.
    private static let viewSymbolSize: CGFloat = 26
    // Collection.dc.html line 30: 2 pt between the title and the subtitle.
    private static let subtitleGap: CGFloat = 2
    // Collection.dc.html line 321: 20 pt between the header and the grid.
    private static let gridTopGap: CGFloat = 20
    // Collection.dc.html line 59: 16 pt between rows, 8 pt between columns.
    private static let rowGap: CGFloat = 16
    private static let columnGap: CGFloat = 8
    // Collection.dc.html line 320: content ends 50 pt above the pill; the Scan bar already leaves 16 of them.
    private static let contentEndGap: CGFloat = 34
    // Collection.dc.html line 35: the empty state is centred with 90 pt extra below it.
    private static let emptyBottomGap: CGFloat = 90

    @Environment(\.dynamicTypeSize) private var typeSize
    /// Open from the moment the grid is first built until its first `onAppear`.
    @State private var firstFrame: OSSignpostIntervalState? = ScreensLog.signposter.beginInterval("Grid first frame")
    @State private var prefetcher = GridPrefetcher()

    /// `canScan` false keeps the Scan button disabled (until launch cleanup has finished).
    public init(
        model: CollectionGridModel,
        thumbnails: any ThumbnailProviding,
        canScan: Bool,
        onOpen: @escaping (ScanID) -> Void,
        onScan: @escaping () -> Void
    ) {
        self.model = model
        self.thumbnails = thumbnails
        self.canScan = canScan
        self.onOpen = onOpen
        self.onScan = onScan
    }

    public var body: some View {
        ScanBarLayout(canScan: canScan, scanIdentifier: AccessibilityID.Grid.scan, onScan: onScan) {
            if model.isEmpty { emptyContent } else { gridContent }
        }
        // The system bar, clear, so the back button is the system's glass one and swipe back works. Hiding the bar
        // turns the swipe off. The title and subtitle are the grid's own (Collection.dc.html).
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear(perform: endFirstFrame)
    }

    private var gridContent: some View {
        let tiles = model.tiles
        return ScrollView {
            VStack(alignment: .leading, spacing: Self.gridTopGap) {
                header
                LazyVGrid(columns: columns, spacing: Self.rowGap) {
                    ForEach(tiles) { tile in
                        GridTileView(
                            tile: tile,
                            shape: model.tileShape,
                            showsWideScanWhole: model.showsWideScansWhole,
                            thumbnails: thumbnails,
                            prefetcher: prefetcher
                        ) {
                            onOpen(tile.id)
                        }
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.bottom, Self.contentEndGap)
        }
        .onChange(of: tiles.map(\.id), initial: true) { _, ids in
            prefetcher.update(ids: ids, provider: thumbnails)
        }
        .onDisappear { prefetcher.stop() }
    }

    /// The empty state is centred in what the header leaves, and scrolls if the text is too large for that.
    private var emptyContent: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    EmptyCollectionView(kind: model.kind, title: model.emptyTitle, message: model.emptyBody)
                        .padding(.horizontal, Tokens.Spacing.s6)
                        .padding(.vertical, Tokens.Spacing.s4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, typeSize.isAccessibilitySize ? 0 : Self.emptyBottomGap)
                }
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.bottom, Self.contentEndGap)
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Self.subtitleGap) {
            HStack(spacing: Self.iconGap) {
                icon
                Text(model.title)
                    .font(Tokens.Typography.title1)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(AccessibilityID.Grid.header)
            }
            Text(model.subtitle)
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch model.kind {
        case .collection(let collection):
            let isLarge = typeSize.isAccessibilitySize
            CollectionBadge(
                collection: collection,
                diameter: isLarge ? Self.largeBadgeDiameter : Self.badgeDiameter,
                symbolSize: isLarge ? Self.largeBadgeSymbol : Self.badgeSymbol
            )
        case .recent:
            viewIcon(ViewSymbol.recent)
        case .all:
            viewIcon(ViewSymbol.all)
        }
    }

    private func viewIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: Self.viewSymbolSize, height: Self.viewSymbolSize)
            .foregroundStyle(Tokens.Color.textSecondary)
            .accessibilityHidden(true)
    }

    private var columns: [GridItem] {
        let item = GridItem(.flexible(), spacing: Self.columnGap, alignment: .top)
        return Array(repeating: item, count: model.columns(largeText: typeSize.isAccessibilitySize))
    }

    private func endFirstFrame() {
        guard let firstFrame else { return }
        ScreensLog.signposter.endInterval("Grid first frame", firstFrame)
        self.firstFrame = nil
    }
}
