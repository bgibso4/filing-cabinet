import Core
import ScreenModels
import SwiftUI

/// Review after the camera, option G's sheet (Review.dc.html lines 209-311): Close, the "New scan" pill and Rescan
/// on top, the scan (paged, with a strip, when there are several), and the sheet with the title, collection, expiry
/// and Save.
public struct ReviewView: View {
    private let model: ReviewModel
    private let onClose: () -> Void
    private let onRescan: () -> Void
    private let onSaved: (SavedScan) -> Void

    @State private var isConfirmingDiscard = false
    @Environment(\.dynamicTypeSize) private var typeSize

    // Review.dc.html lines 211-212: the page is at most 358 pt wide (16 pt in from each side) and, in the sheet state,
    // 332 pt tall, 16 pt below the top buttons.
    private static let pageMaxWidth: CGFloat = 358
    private static let pageMaxHeight: CGFloat = 332
    // No mock for the largest text (12-03 is the card): the scan keeps this much height while the sheet scrolls.
    private static let pageMinHeight: CGFloat = 120

    /// `onClose` runs after the user confirms the discard; `onSaved` after a successful save.
    public init(
        model: ReviewModel,
        onClose: @escaping () -> Void,
        onRescan: @escaping () -> Void,
        onSaved: @escaping (SavedScan) -> Void
    ) {
        self.model = model
        self.onClose = onClose
        self.onRescan = onRescan
        self.onSaved = onSaved
    }

    public var body: some View {
        ReviewLayout {
            VStack(spacing: 0) {
                topBar
                pages
                    .frame(maxWidth: Self.pageMaxWidth)
                    .frame(minHeight: Self.pageMinHeight, maxHeight: Self.pageMaxHeight)
                    .padding(.top, Tokens.Spacing.s4)
                    .padding(.horizontal, Tokens.Spacing.s4)
                Spacer(minLength: 0)
                if model.pages.count > 1 {
                    // The glass bar's own padding makes up the rest of the mock's 12 pt.
                    PageStrip(pages: model.pages, currentPage: model.currentPage)
                        .padding(.vertical, Tokens.Spacing.s3 - PageStripTile.barPadding)
                }
            }
            ReviewSheet(model: model, onSave: save)
        }
        // The sheet sits 8 pt above the screen's bottom edge, over the home indicator's strip, as in the mock.
        // The keyboard still pushes it up.
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Tokens.Color.bgGrouped)
        // Reading starts as review opens, once per page set (a rescan's pages start their own).
        .task { await model.startReading() }
        .alert(Text("Discard this scan?", bundle: #bundle), isPresented: $isConfirmingDiscard) {
            Button(role: .cancel) {
            } label: {
                Text("Keep editing", bundle: #bundle)
            }
            Button(role: .destructive, action: discard) { Text("Discard", bundle: #bundle) }
        } message: {
            Text(model.discardMessage)
        }
        .alert(
            model.saveAlert?.title ?? "",
            isPresented: Binding(
                get: { model.saveAlert != nil },
                set: { isPresented in
                    if !isPresented { model.dismissSaveAlert() }
                }),
            presenting: model.saveAlert
        ) { _ in
            Button(role: .cancel, action: model.dismissSaveAlert) { Text("Not now", bundle: #bundle) }
            Button(action: retrySave) { Text("Try again", bundle: #bundle) }
        } message: { alert in
            Text(alert.message)
        }
    }

    // MARK: Top

    /// Close, the pill and Rescan on one line. At accessibility sizes the pill gets its own line under the buttons, so
    /// "New scan" wraps rather than squeezing between them.
    private var topBar: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: Tokens.Spacing.s2) {
                    HStack {
                        closeButton
                        Spacer(minLength: Tokens.Spacing.s2)
                        rescanButton
                    }
                    pill
                }
            } else {
                HStack(spacing: Tokens.Spacing.s2) {
                    closeButton
                    pill.frame(maxWidth: .infinity)
                    rescanButton
                }
            }
        }
        // Nothing leaves review while it saves.
        .disabled(model.isSaving)
        .padding(.horizontal, Tokens.Spacing.s4)
    }

    private var closeButton: some View {
        GlassCircleButton(
            systemImage: "xmark",
            // Subheadline is the mock's 15 pt glyph.
            font: Tokens.Typography.subheadline.weight(.semibold),
            label: Text("Close", bundle: #bundle),
            identifier: AccessibilityID.Review.close
        ) {
            isConfirmingDiscard = true
        }
    }

    private var pill: some View {
        PagePill(title: Text("New scan", bundle: #bundle), identifier: AccessibilityID.Review.pagePill) {
            Text(model.pageCountText)
        }
    }

    private var rescanButton: some View {
        GlassCircleButton(
            systemImage: "arrow.counterclockwise",
            // Title 2 is closest to the mock's 24 pt glyph.
            font: Tokens.Typography.title2.weight(.regular),
            label: Text("Rescan", bundle: #bundle),
            identifier: AccessibilityID.Review.rescan,
            action: onRescan
        )
    }

    // MARK: Pages

    @ViewBuilder
    private var pages: some View {
        if model.pages.count > 1 {
            @Bindable var model = model
            Pager(count: model.pages.count, selection: $model.currentPage) { index in
                page(at: index)
            }
        } else {
            page(at: 0)
        }
    }

    /// The pill says which page this is, so the image itself is not an accessibility element.
    private func page(at index: Int) -> some View {
        Image(decorative: model.pages[index], scale: 1)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func save() {
        Task {
            if let saved = await model.save() { onSaved(saved) }
        }
    }

    private func retrySave() {
        Task {
            if let saved = await model.retrySave() { onSaved(saved) }
        }
    }

    /// Stops reading before review ends.
    private func discard() {
        model.discard()
        onClose()
    }
}
