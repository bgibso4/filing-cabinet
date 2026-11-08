import Core
import Library
import ScreenModels
import SwiftUI

/// One scan in Trash (Trash.dc.html lines 46-58): its thumbnail, the collection's dot, the title and the days left.
/// A tap opens it, or ticks it while selecting; a long press lifts the thumbnail with Open, Restore and Delete now
/// (09-03). VoiceOver reads it as one element with Restore and Delete now as actions.
struct TrashTileView: View {
    let tile: TrashTile
    let model: TrashModel
    let thumbnails: any ThumbnailProviding
    let onOpen: () -> Void

    // Trash.dc.html line 226: every tile's thumbnail is 136 pt tall.
    private static let thumbnailHeight: CGFloat = 136
    // Trash.dc.html line 47: 2 pt between the tile's rows; line 56: 4 pt more above the title.
    private static let rowGap: CGFloat = 2
    // Trash.dc.html line 56: 5 pt between the dot and the title.
    private static let dotGap: CGFloat = 5
    // Trash.dc.html line 49: a ticked scan's image fades to 75%.
    private static let selectedImageOpacity = 0.75

    @Environment(\.dynamicTypeSize) private var typeSize
    /// The thumbnail's size, so the long-press preview lifts just the image, as 09-03 shows.
    @State private var thumbnailSize: CGSize = .zero

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: Self.rowGap) {
                thumbnail
                    .opacity(isSelected ? Self.selectedImageOpacity : 1)
                    .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
                    .overlay(alignment: .bottomTrailing) {
                        if model.isSelecting { TrashCheckCircle(isOn: isSelected) }
                    }
                    .onGeometryChange(for: CGSize.self, of: \.size) { thumbnailSize = $0 }
                HStack(spacing: Self.dotGap) {
                    CollectionDot(collection: tile.collection)
                    Text(tile.title)
                        .font(Tokens.Typography.footnote.weight(.semibold))
                        .foregroundStyle(Tokens.Color.textPrimary)
                        // Trash.dc.html line 56: one line with an ellipsis; above the default size it wraps rather
                        // than cutting off (requirements 06 · Accessibility).
                        .lineLimit(typeSize <= .large ? 1 : nil)
                }
                .padding(.top, Tokens.Spacing.s1)
                Text(tile.daysLeftText)
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityID.Trash.tile(tile.id))
        .accessibilityAction(named: Text("Restore", bundle: #bundle), restore)
        .accessibilityAction(named: Text("Delete now", bundle: #bundle), delete)
        .contextMenu {
            if !model.isSelecting { menu }
        } preview: {
            thumbnail.frame(width: thumbnailSize.width)
        }
        // Delete now asks from the tile it deletes.
        .trashConfirmationDialog(
            model.tileConfirmation(tile.id), cancel: model.cancelConfirmation, perform: model.performConfirmation)
    }

    private var isSelected: Bool { model.selected.contains(tile.id) }

    private var thumbnail: some View {
        ThumbnailView(id: tile.id, page: 0, provider: thumbnails)
            .frame(height: Self.thumbnailHeight)
    }

    /// Trash.dc.html lines 151-155.
    @ViewBuilder
    private var menu: some View {
        Button(action: onOpen) { Text("Open", bundle: #bundle) }
        // A menu shows a button's second text as its subtitle.
        Button(action: restore) {
            Label {
                Text("Restore", bundle: #bundle)
            } icon: {
                Image(systemName: "arrow.uturn.backward")
            }
            Text(model.restoreLine(for: tile.id))
        }
        Button(role: .destructive, action: delete) {
            Label {
                Text("Delete now", bundle: #bundle)
            } icon: {
                Image(systemName: "trash")
            }
        }
    }

    private func tap() {
        if model.isSelecting { model.toggle(tile.id) } else { onOpen() }
    }

    /// No confirmation (M10); VoiceOver hears where it went (M19).
    private func restore() {
        if let announcement = model.restore([tile.id]) {
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    private func delete() {
        model.confirmDelete([tile.id])
    }
}
