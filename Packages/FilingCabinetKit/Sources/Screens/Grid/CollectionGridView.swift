import Core
import Library
import ScreenModels
import SwiftUI
import os

/// A collection, Recent or All Scans: a back button, the title in the bar (resting small, #62; large and still when
/// empty, B5), a lazy grid of scans (or the empty state) and Scan. Select picks several scans; in Scan's place, Share
/// sends them, Move to Trash moves them and the heart favourites them (#68, as Trash's select mode; B12).
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
    // .superpowers/plandoc/p4 A1 (`.circle`): Share and the heart are 56 pt glass circles with a 24 pt glyph, 16 pt in
    // from the edges. Title 2 is closest to the glyph, as on the viewer's bar.
    private static let circleDiameter: CGFloat = 56
    private static let circleFont = Tokens.Typography.title2.weight(.regular)

    @Environment(\.dynamicTypeSize) private var typeSize
    /// Open from the moment the grid is first built until its first `onAppear`.
    @State private var firstFrame: OSSignpostIntervalState? = ScreensLog.signposter.beginInterval("Grid first frame")
    @State private var prefetcher = GridPrefetcher()
    @State private var isConfirmingMove = false
    /// Counts the drops in Favorites that changed the order, for a light tap as each one lands.
    @State private var drops = 0

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
        return ScanBarLayout(
            canScan: canScan,
            scanIdentifier: AccessibilityID.Grid.scan,
            onScan: onScan,
            replacement: model.isSelecting ? selectBar : nil
        ) {
            // One header for both states, so a grid emptying on screen changes its rest in place (HeaderScrollView).
            HeaderScrollView(
                title: Text(model.title),
                subtitle: model.subtitle,
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
            .onDisappear {
                prefetcher.stop()
                model.exportEnded()
            }
        }
        .toolbar {
            // Always there, greyed out while the grid is empty, as in Trash (B14); as Cancel it stays on, should the
            // grid empty mid-selection. Built again when the text size changes, as Trash's (the bar doesn't restyle a
            // button it already holds).
            ToolbarItem(placement: .topBarTrailing) {
                SelectButton(
                    isSelecting: model.isSelecting,
                    identifier: AccessibilityID.Grid.select,
                    action: model.toggleSelecting
                )
                .disabled(model.isEmpty && !model.isSelecting).id(typeSize)
            }
        }
        .editAlert(model.editAlert, dismiss: model.dismissEditAlert)
        .onAppear(perform: endFirstFrame)
    }

    /// The bar in Scan's place while selecting (B12, A1): Share, Move to Trash and the heart, all glass, all off until
    /// a scan is ticked (M24). At accessibility sizes the pill takes a row of its own above the circles, so its title
    /// keeps the width and never breaks mid-word, as Trash's bar stacks (no mock; Ben to confirm).
    private var selectBar: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: Tokens.Spacing.s3) {
                    moveButton
                    HStack {
                        shareButton
                        Spacer(minLength: 0)
                        favoriteButton
                    }
                }
            } else {
                HStack(spacing: Tokens.Spacing.s3) {
                    shareButton
                    moveButton.frame(maxWidth: .infinity)
                    favoriteButton
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.s4)
        .disabled(!model.canAct)
    }

    /// One PDF per selected scan (B7, M10).
    private var shareButton: some View {
        ShareLink(
            items: model.sharedPDFs,
            preview: { SharePreview($0.suggestedFileName) },
            label: {
                GlassCircleLabel(
                    systemImage: "square.and.arrow.up", font: Self.circleFont, diameter: Self.circleDiameter)
            }
        )
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Share", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.Grid.share)
    }

    /// "Move 2 to Trash", or "Move to Trash" where the count doesn't fit (B12). It asks first, as the viewer's Trash
    /// button does (06-04, M19).
    private var moveButton: some View {
        GlassPillButton(identifier: AccessibilityID.Grid.moveToTrash, action: confirmMove) {
            ViewThatFits(in: .horizontal) {
                Text(model.moveTitle).lineLimit(1)
                Text(model.shortMoveTitle)
            }
        }
        .moveToTrashConfirmation(isPresented: $isConfirmingMove, message: model.moveMessage, move: moveSelected)
    }

    /// Favorite, or Remove from Favorites when every selected scan is one; either ends select mode.
    private var favoriteButton: some View {
        GlassCircleButton(
            systemImage: model.selectionIsFavorite ? "heart.fill" : "heart",
            font: Self.circleFont,
            label: Text(model.favoriteTitle),
            identifier: AccessibilityID.Grid.favorite,
            diameter: Self.circleDiameter,
            action: model.favoriteSelected
        )
    }

    private func confirmMove() {
        isConfirmingMove = true
    }

    private func moveSelected() {
        // The move ends select mode, which takes away the bar the confirmation hangs on, possibly before the dialog
        // writes its dismissal back: cleared first, so it can't come up again unasked on the next Select (review M2).
        // Not an onChange of isSelecting: one after the toolbar dropped the bar's Select (seen in the UI tests).
        isConfirmingMove = false
        if let announcement = model.moveSelectedToTrash() {
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    private func grid(_ tiles: [GridTile]) -> some View {
        // Read once, not per tile, and only while selecting: it filters the grid's scans.
        let selected = model.isSelecting ? model.selected : []
        return LazyVGrid(columns: columns, spacing: Self.rowGap) {
            ForEach(tiles) { tile in
                GridTileView(
                    tile: tile,
                    shape: model.tileShape,
                    showsWideScanWhole: model.showsWideScansWhole,
                    thumbnails: thumbnails,
                    prefetcher: prefetcher,
                    isSelecting: model.isSelecting,
                    isSelected: selected.contains(tile.id)
                ) {
                    if model.isSelecting { model.toggle(tile.id) } else { onOpen(tile.id) }
                } onToggleFavorite: {
                    model.toggleFavorite(tile.id)
                } onMoveEarlier: {
                    model.moveFavoriteEarlier(tile.id)
                } onMoveLater: {
                    model.moveFavoriteLater(tile.id)
                }
            }
            .reorderable()
        }
        // Only Favorites has an order of your own (M8); not while selecting, where a tap ticks (P5).
        .reorderContainer(for: GridTile.self, isEnabled: model.kind == .favorites && !model.isSelecting) { difference in
            let destination: ScanID? =
                switch difference.destination.position {
                case .before(let id): id
                case .end: nil
                }
            if model.moveFavorites(difference.sources, before: destination) { drops += 1 }
        }
        .sensoryFeedback(.selection, trigger: drops)
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
