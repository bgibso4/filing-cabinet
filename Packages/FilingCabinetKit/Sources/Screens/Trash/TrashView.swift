import Core
import Library
import ScreenModels
import SwiftUI

/// Trash (09-01 … 09-11): the scans soonest gone first, with Select for several at once, a long press for one, and Empty
/// Trash. Deleting asks first; restoring doesn't (M10).
public struct TrashView: View {
    private let model: TrashModel
    private let thumbnails: any ThumbnailProviding
    private let onOpen: (ScanID) -> Void

    // Trash.dc.html lines 19 and 25: the title starts 12 pt under the 44 pt back button. The system bar is 10 pt taller
    // than the mock's button, so 2 pt are left to add.
    private static let titleTopGap: CGFloat = 2
    // Trash.dc.html line 27: 2 pt between the title and the subtitle.
    private static let subtitleGap: CGFloat = 2
    // Trash.dc.html lines 25 and 32: the grid starts at 190, 17 pt under the subtitle (110 + 41 + 2 + 20).
    private static let gridTopGap: CGFloat = 17
    // Trash.dc.html line 32: 16 pt between rows, 8 pt between columns; 3 columns, 2 at large text as in every grid
    // (requirements 06 · Accessibility).
    private static let rowGap: CGFloat = 16
    private static let columnGap: CGFloat = 8
    private static let columnCount = 3
    private static let largeTextColumnCount = 2
    // Collection.dc.html line 320: content ends 50 pt above the pill; the bar already leaves 16 of them.
    private static let contentEndGap: CGFloat = 34
    // Trash.dc.html lines 26 and 65: the empty state starts at 300, 149 pt under the title (110 + 41).
    private static let emptyTopGap: CGFloat = 149
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
        content
            // The system bar, clear, as on the grids: the back button is the system's glass one and swipe back works.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !model.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { selectButton }
                }
            }
            .trashConfirmationAlert(
                model.confirmation, cancel: model.cancelConfirmation, perform: performConfirmation
            )
            .editAlert(model.editAlert, dismiss: model.dismissEditAlert)
    }

    @ViewBuilder
    private var content: some View {
        if model.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    TrashEmptyView()
                        .padding(.horizontal, Tokens.Spacing.s4)
                        .padding(.top, typeSize.isAccessibilitySize ? Tokens.Spacing.s8 : Self.emptyTopGap)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.bottom, Tokens.Spacing.s8)
            }
            .background(Tokens.Color.bgGrouped)
        } else {
            BottomBarLayout {
                grid
            } bar: {
                if model.isSelecting { selectionBar } else { emptyTrashButton }
            }
        }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.gridTopGap) {
                header
                LazyVGrid(columns: columns, spacing: Self.rowGap) {
                    ForEach(model.tiles) { tile in
                        TrashTileView(tile: tile, model: model, thumbnails: thumbnails) { onOpen(tile.id) }
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.bottom, Self.contentEndGap)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Self.subtitleGap) {
            Text("Trash", bundle: #bundle)
                .font(Tokens.Typography.largeTitle)
                .tracking(Tokens.Typography.largeTitleTracking)
                .foregroundStyle(Tokens.Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(AccessibilityID.Trash.header)
            if let subtitle = model.subtitle {
                // While selecting, "2 selected" is in the primary colour and semibold (Trash.dc.html line 245).
                Text(subtitle)
                    .font(Tokens.Typography.subheadline)
                    .fontWeight(model.isSelecting ? .semibold : .regular)
                    .foregroundStyle(model.isSelecting ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
            }
        }
        .padding(.top, Self.titleTopGap)
    }

    private var columns: [GridItem] {
        let item = GridItem(.flexible(), spacing: Self.columnGap, alignment: .top)
        return Array(
            repeating: item, count: typeSize.isAccessibilitySize ? Self.largeTextColumnCount : Self.columnCount)
    }

    /// Select, or Cancel while selecting: the system draws it as a glass pill beside the back button.
    private var selectButton: some View {
        Button(action: model.toggleSelecting) {
            model.isSelecting ? Text("Cancel", bundle: #bundle) : Text("Select", bundle: #bundle)
        }
        .font(Tokens.Typography.headline)
        .accessibilityIdentifier(AccessibilityID.Trash.select)
    }

    private var emptyTrashButton: some View {
        Button(action: model.confirmEmpty) {
            Text("Empty Trash", bundle: #bundle)
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Color.destructive)
                .padding(.horizontal, Self.emptyTrashPadding)
                .frame(minHeight: Self.emptyTrashHeight)
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(.capsule)
                // One element for the whole pill, as the Scan button does, so the audit measures the text against it.
                .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Trash.emptyTrash)
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
            onRestore: restoreSelected
        )
        .padding(.horizontal, Self.selectionBarInset)
    }

    private func performConfirmation() {
        Task {
            if let announcement = await model.performConfirmation() {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
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
