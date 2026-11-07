import Core
import Library
import ScreenModels
import SwiftUI

/// One scan in a grid: its thumbnail, title and time left. VoiceOver reads it as one element.
struct GridTileView: View {
    let tile: GridTile
    let shape: CollectionGridModel.TileShape
    let showsWideScanWhole: Bool
    let thumbnails: any ThumbnailProviding
    let prefetcher: GridPrefetcher
    let onOpen: () -> Void

    // Collection.dc.html line 317: Wallet's tiles are 1.55 wide per 1 tall, every other tile is 3:4.
    private static let cardAspect: CGFloat = 1.55
    private static let pageAspect: CGFloat = 3 / 4
    // Collection.dc.html line 61: 2 pt between the tile's rows; line 66: 4 pt more above the title.
    private static let rowGap: CGFloat = 2
    // Collection.dc.html line 66: 5 pt between the dot and the title.
    private static let dotGap: CGFloat = 5

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Self.rowGap) {
                ThumbnailView(
                    id: tile.id,
                    page: 0,
                    provider: thumbnails,
                    showsWideImagesWhole: showsWideScanWhole
                )
                .aspectRatio(shape == .card ? Self.cardAspect : Self.pageAspect, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
                .flightTarget(.tile(tile.id))
                HStack(spacing: Self.dotGap) {
                    if let dot = tile.dot { CollectionDot(collection: dot) }
                    Text(tile.title)
                        .font(Tokens.Typography.footnote.weight(.semibold))
                        .foregroundStyle(Tokens.Color.textPrimary)
                        // Collection.dc.html line 68: one line with an ellipsis; above the default size it wraps
                        // rather than cutting off (requirements 06 · Accessibility).
                        .lineLimit(typeSize <= .large ? 1 : nil)
                }
                .padding(.top, Tokens.Spacing.s1)
                Text(tile.timeLeft)
                    .font(Tokens.Typography.caption)
                    .fontWeight(tile.isSoon ? .semibold : .regular)
                    .foregroundStyle(tile.isSoon ? Tokens.Color.expirySoon : Tokens.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tile.accessibilityLabel)
        .accessibilityIdentifier(AccessibilityID.Grid.tile(tile.id))
        .onAppear { prefetcher.tileAppeared(tile.id) }
        .onDisappear { prefetcher.tileDisappeared(tile.id) }
    }
}
