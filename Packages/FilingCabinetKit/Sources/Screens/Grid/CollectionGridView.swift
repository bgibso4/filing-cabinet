import Core
import Library
import ScreenModels
import SwiftUI
import os

/// A collection, Recent or All Scans: a back button, the title in the bar (resting small, #62; large and still when
/// empty, B5), a lazy grid of scans (or the empty state) and Scan.
public struct CollectionGridView: View {
    private let model: CollectionGridModel
    private let thumbnails: any ThumbnailProviding
    private let canScan: Bool
    private let onOpen: (ScanID) -> Void
    private let onScan: () -> Void

    // Collection.dc.html line 321: 20 pt between the header and the grid; with the title in the bar, under the bar.
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
        // Localizing the tiles is what costs (see `CollectionGridModel.tiles`), so they are built once per update.
        let tiles = model.tiles
        return ScanBarLayout(canScan: canScan, scanIdentifier: AccessibilityID.Grid.scan, onScan: onScan) {
            // One header for both states, so a grid emptying on screen changes its rest in place (HeaderScrollView).
            HeaderScrollView(
                title: Text(model.title),
                subtitle: Text(model.subtitle),
                identifier: AccessibilityID.Grid.header,
                rest: model.isEmpty ? .large : .small,
                // Empty holds still (B5), except at accessibility sizes, where the empty state's text can run past the
                // Scan button and has to scroll to be read whole.
                scrolls: !model.isEmpty || typeSize.isAccessibilitySize
            ) {
                if model.isEmpty { emptyContent } else { grid(tiles) }
            }
            .onChange(of: tiles.map(\.id), initial: true) { _, ids in
                prefetcher.update(ids: ids, provider: thumbnails)
            }
            .onDisappear { prefetcher.stop() }
        }
        .onAppear(perform: endFirstFrame)
    }

    private func grid(_ tiles: [GridTile]) -> some View {
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
        .padding(.top, Self.gridTopGap)
        .padding(.horizontal, Tokens.Spacing.s4)
        .padding(.bottom, Self.contentEndGap)
    }

    /// The empty state, centred in what the header leaves (at accessibility sizes, from the top, scrolling).
    private var emptyContent: some View {
        EmptyCollectionView(kind: model.kind, title: model.emptyTitle, message: model.emptyBody)
            .padding(.horizontal, Tokens.Spacing.s6)
            .padding(.vertical, Tokens.Spacing.s4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, typeSize.isAccessibilitySize ? 0 : Self.emptyBottomGap)
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.bottom, Self.contentEndGap)
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
