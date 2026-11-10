import Core
import Library
import ScreenModels
import SwiftUI

/// Trash (09-01 … 09-11): the scans soonest gone first, with Select for several at once, a long press for one, and Empty
/// Trash. Deleting asks first, from the button that asked; restoring doesn't (M10).
public struct TrashView: View {
    private let model: TrashModel
    private let thumbnails: any ThumbnailProviding
    private let onOpen: (ScanID) -> Void

    // Trash.dc.html lines 25 and 32: the grid starts 17 pt under the subtitle; with the title in the bar, under the bar.
    private static let gridTopGap: CGFloat = 17
    // Trash.dc.html line 32: 16 pt between rows, 8 pt between columns; 3 columns, 2 at large text as in every grid
    // (requirements 06 · Accessibility).
    private static let rowGap: CGFloat = 16
    private static let columnGap: CGFloat = 8
    private static let columnCount = 3
    private static let largeTextColumnCount = 2
    // Collection.dc.html line 320: content ends 50 pt above the pill; the bar already leaves 16 of them.
    private static let contentEndGap: CGFloat = 34
    // Trash.dc.html line 126: Empty Trash is 52 pt tall with 28 pt either side of its label.
    private static let emptyTrashHeight: CGFloat = 52
    private static let emptyTrashPadding: CGFloat = 28
    // Trash.dc.html line 120: Delete and Restore are 20 pt in from the sides.
    private static let selectionBarInset: CGFloat = 20

    @Environment(\.dynamicTypeSize) private var typeSize

    public init(model: TrashModel, thumbnails: any ThumbnailProviding, onOpen: @escaping (ScanID) -> Void) {
        self.model = model
        self.thumbnails = thumbnails
        self.onOpen = onOpen
    }

    public var body: some View {
        BottomBarLayout {
            // One header for every state, so Trash emptying on screen changes its rest in place (HeaderScrollView).
            HeaderScrollView(
                title: Text("Trash", bundle: #bundle),
                subtitle: model.subtitle,
                rest: model.isEmpty ? .large : .small,
                // Empty holds still (B5), except at accessibility sizes, where the empty state's text runs past the
                // screen and has to scroll to be read whole (E6).
                scrolls: !model.isEmpty || typeSize.isAccessibilitySize
            ) {
                if model.isEmpty { emptyContent } else { grid }
            }
        } bar: {
            if model.isSelecting {
                selectionBar
            } else if !model.isEmpty {
                emptyTrashButton
            }
        }
        .toolbar {
            // Always there, greyed out while Trash is empty, as in Passwords' Recently Deleted (B14); as Cancel it stays on,
            // should Trash empty mid-selection (a purge). Built again when
            // the text size changes: the bar doesn't restyle a button it already holds, so Select would keep the old
            // size (the largest-text audit's Dynamic Type check finds it).
            ToolbarItem(placement: .topBarTrailing) {
                SelectButton(
                    isSelecting: model.isSelecting,
                    identifier: AccessibilityID.Trash.select,
                    action: model.toggleSelecting
                )
                .disabled(model.isEmpty && !model.isSelecting).id(typeSize)
            }
        }
        .editAlert(model.editAlert, dismiss: model.dismissEditAlert)
    }

    private var grid: some View {
        // Plan 3, E8 (Ben's Passwords screenshot): the notice sits a row gap above the tiles.
        VStack(spacing: Self.rowGap) {
            if let notice = model.notice { TrashNotice(text: notice) }
            LazyVGrid(columns: columns, spacing: Self.rowGap) {
                ForEach(model.tiles) { tile in
                    TrashTileView(tile: tile, model: model, thumbnails: thumbnails) { onOpen(tile.id) }
                }
            }
        }
        .padding(.top, Self.gridTopGap)
        .padding(.horizontal, Tokens.Spacing.s4)
        .padding(.bottom, Self.contentEndGap)
    }

    /// The empty state, centred in what the header leaves, as in Recently Deleted (at accessibility sizes, from the
    /// top, scrolling).
    private var emptyContent: some View {
        TrashEmptyView()
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.top, typeSize.isAccessibilitySize ? Tokens.Spacing.s8 : 0)
            .frame(maxWidth: .infinity, maxHeight: typeSize.isAccessibilitySize ? nil : .infinity)
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.bottom, Tokens.Spacing.s8)
    }

    private var columns: [GridItem] {
        let item = GridItem(.flexible(), spacing: Self.columnGap, alignment: .top)
        return Array(
            repeating: item, count: typeSize.isAccessibilitySize ? Self.largeTextColumnCount : Self.columnCount)
    }

    private var emptyTrashButton: some View {
        Button(action: model.confirmEmpty) {
            Text("Empty Trash", bundle: #bundle)
                .font(Tokens.Typography.headline)
                // Neutral, like Select; the confirmation's action is the red one (Ben, 2026-11-08, after Photos).
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.horizontal, Self.emptyTrashPadding)
                .frame(minHeight: Self.emptyTrashHeight)
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(.capsule)
                // One element for the whole pill, as the Scan button does, so the audit measures the text against it.
                .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Trash.emptyTrash)
        .trashConfirmationDialog(
            model.emptyConfirmation, cancel: model.cancelConfirmation, perform: model.performConfirmation)
    }

    /// Delete N and Restore N (09-02), both off until a scan is ticked.
    private var selectionBar: some View {
        TrashActionBar(
            deleteTitle: model.deleteTitle,
            restoreTitle: model.restoreTitle,
            deleteIdentifier: AccessibilityID.Trash.deleteSelected,
            restoreIdentifier: AccessibilityID.Trash.restoreSelected,
            canAct: model.canAct,
            onDelete: deleteSelected,
            onRestore: restoreSelected,
            confirmation: model.selectionConfirmation,
            onCancel: model.cancelConfirmation,
            onConfirm: model.performConfirmation
        )
        .padding(.horizontal, Self.selectionBarInset)
    }

    private func deleteSelected() {
        model.confirmDelete(Array(model.selected))
    }

    /// No confirmation (M10); VoiceOver hears what happened (M19).
    private func restoreSelected() {
        if let announcement = model.restore(Array(model.selected)) {
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}
