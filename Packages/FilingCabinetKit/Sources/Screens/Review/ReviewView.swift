import Core
import ScreenModels
import SwiftUI

/// Review after the camera, option G (Review.dc.html lines 209-311): Close, the "New scan" pill and Rescan on top, the
/// scan (paged, with a strip, when there are several), and below it the suggestion card or the sheet with the title,
/// collection, expiry and Save. When the card gives way to the sheet, the sheet rises over it and the scan shrinks to
/// make room (the growth mock, option 3: claude.ai/artifact/ULgeFhB5rS6qNzMwLebT5N).
public struct ReviewView: View {
    @Bindable private var model: ReviewModel
    private let onClose: () -> Void
    private let onRescan: () -> Void
    private let onSaved: (SavedScan) -> Void

    @State private var isConfirmingDiscard = false
    /// Where a page fits at rest, in global coordinates.
    @State private var pageRegion = CGRect.zero
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.reducesMotion) private var reducesMotion

    // Review.dc.html lines 211-212: the page is at most 358 pt wide (16 pt in from each side) and, in the sheet state,
    // 332 pt tall, 16 pt below the top buttons.
    private static let pageMaxWidth: CGFloat = 358
    private static let pageMaxHeight: CGFloat = 332
    // Review.dc.html line 397: with the card, the page is at most 598 pt tall, or 552 pt above a page strip.
    private static let cardPageMaxHeight: CGFloat = 598
    private static let cardStripPageMaxHeight: CGFloat = 552
    // ULgeF `.page` and `.sheet`: the scan shrinks and the sheet rises over 0.35-0.4 s on cubic-bezier(.3, .7, .2, 1).
    private static let growth = Animation.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.4)
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
                    .environment(\.colorScheme, controlsScheme ?? colorScheme)
                // Where a page fits at rest; the pager behind everything draws it.
                Color.clear
                    .frame(maxWidth: Self.pageMaxWidth)
                    .frame(minHeight: Self.pageMinHeight, maxHeight: pageMaxHeight)
                    .overlay { sweep }
                    // Measured inside the padding: the page fits the region itself.
                    .onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .global)
                    } action: { region in
                        // The page follows the region as the card gives way to the sheet; the first fit is not animated.
                        withAnimation(pageRegion.isEmpty || reducesMotion ? nil : Self.growth) {
                            pageRegion = region
                        }
                    }
                    .padding(.top, Tokens.Spacing.s4)
                    .padding(.horizontal, Tokens.Spacing.s4)
                Spacer(minLength: 0)
                if model.pages.count > 1 {
                    // The glass bar's own padding makes up the rest of the mock's 12 pt.
                    PageStrip(
                        pages: model.pages, currentPage: $model.currentPage, label: model.pageAccessibilityLabel
                    )
                    .padding(.vertical, Tokens.Spacing.s3 - PageStripTile.barPadding)
                    .environment(\.colorScheme, controlsScheme ?? colorScheme)
                }
            }
            bottom
        }
        .animation(reducesMotion ? nil : Self.growth, value: model.presentation)
        // The sheet sits 8 pt above the screen's bottom edge, over the home indicator's strip, as in the mock.
        // The keyboard still pushes it up.
        .ignoresSafeArea(.container, edges: .bottom)
        .background { pager }
        .background(Tokens.Color.bgGrouped)
        // Reading starts as review opens, once per page set (a rescan's pages start their own).
        .task { await model.startReading() }
        // M11: a light tap and VoiceOver's "Suggested: City Pharmacy receipt, Receipts" when the suggestion lands.
        .sensoryFeedback(.selection, trigger: model.suggestionAnnouncement)
        .onChange(of: model.suggestionAnnouncement) { _, announcement in
            if let announcement { AccessibilityNotification.Announcement(announcement).post() }
        }
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

    // MARK: Bottom

    /// The card, or the sheet rising over it. One subview for `ReviewLayout`, though both show while one gives way.
    private var bottom: some View {
        ZStack(alignment: .bottom) {
            switch model.presentation {
            case .card(let isReading):
                ReviewCard(model: model, isReading: isReading, onSave: save)
                    .transition(.opacity)
            case .sheet:
                ReviewSheet(model: model, onSave: save)
                    .transition(.move(edge: .bottom))
            }
        }
    }

    /// The card leaves the scan more room than the sheet.
    private var pageMaxHeight: CGFloat {
        guard model.presentation != .sheet else { return Self.pageMaxHeight }
        return model.pages.count > 1 ? Self.cardStripPageMaxHeight : Self.cardPageMaxHeight
    }

    /// The scanner bar over the page (not the region around it) while the model reads, unless the page is zoomed.
    @ViewBuilder private var sweep: some View {
        if model.presentation == .card(isReading: true), !model.isPageZoomed,
            model.pages.indices.contains(model.currentPage), model.pages[model.currentPage].height > 0
        {
            let page = model.pages[model.currentPage]
            ScanSweep()
                .aspectRatio(CGFloat(page.width) / CGFloat(page.height), contentMode: .fit)
        }
    }

    /// A zoomed page fills the screen with paper, white in both appearances, so the glass controls over it take the
    /// light appearance, as the viewer's do.
    private var controlsScheme: ColorScheme? { model.isPageZoomed ? .light : nil }

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

    /// Full screen behind everything, as in the viewer, so a zoomed page fills the screen under the glass controls (the
    /// sheet stays on top). At rest each page fits the region the layout keeps for it (`pageRegion`).
    private var pager: some View {
        GeometryReader { proxy in
            let fitInsets = fitInsets(in: proxy.frame(in: .global))
            Pager(count: model.pages.count, selection: $model.currentPage) { index in
                // The pill says which page this is, so the image itself is not an accessibility element.
                ZoomablePageView(
                    image: model.pages[index],
                    pageKey: index,
                    isCurrent: index == model.currentPage,
                    label: nil,
                    fitInsets: fitInsets,
                    animatesFit: true
                ) { isZoomed in
                    if index == model.currentPage { model.isPageZoomed = isZoomed }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// The page region as insets from the screen's edges.
    private func fitInsets(in screen: CGRect) -> UIEdgeInsets {
        guard !pageRegion.isEmpty else { return .zero }
        return UIEdgeInsets(
            top: pageRegion.minY - screen.minY,
            left: pageRegion.minX - screen.minX,
            bottom: screen.maxY - pageRegion.maxY,
            right: screen.maxX - pageRegion.maxX)
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
