import Core
import Library
import ScreenModels
import SwiftUI

/// A scan, like Photos: its pages, a back button, a header pill, the page strip and the bottom bar. Per A2 there is no
/// More button. The pill and Info open Details, and so does a swipe up on a page at rest, under the finger (M5). As it
/// rises (`detailsProgress`) the pill, strip and bar fade away (B2) and the page fits above it, a step every frame
/// (07-01, #61). Opened from Trash (09-04) it has Close for back, a pill with the days left in Trash that opens nothing
/// (a scan in Trash is read-only until restored), and Delete now and Restore for the bar.
public struct ViewerView: View {
    @Bindable private var model: ViewerModel
    private let pages: any PageImageProviding
    private let thumbnails: any ThumbnailProviding
    /// The Details panel's height, 0 until it is measured.
    private let detailsHeight: CGFloat
    /// How far Details is up for the page's fit: 0 closed, 1 open.
    private let detailsProgress: CGFloat
    /// How far Details is up for the chrome's fade. The same as `detailsProgress`, except under Reduce Motion, where the
    /// fit jumps and the chrome still fades with the panel (B11).
    private let chromeProgress: CGFloat
    private let onDetails: () -> Void
    /// A swipe up on the page, moving Details with the finger (M5).
    private let onDetailsDrag: (DetailsDrag) -> Void
    /// After Restore, opened from Trash.
    private let onRestored: () -> Void

    // ScanView.dc.html line 221: the pill is at most 240 pt wide; Trash.dc.html line 164: 250 pt opened from Trash.
    private static let headerMaxWidth: CGFloat = 240
    private static let trashHeaderMaxWidth: CGFloat = 250
    // ScanView.dc.html line 223: 5 pt between the dot and the text.
    private static let dotGap: CGFloat = 5
    // ScanView.dc.html lines 367-368: at rest a page fits from 14 pt under the header's row (top 120, the row ending at
    // 106) to 164 pt above the screen's bottom edge (120 + 560 of 844), 34 of them the safe area. Measured from the safe
    // area, which holds the bar.
    private static let pageFitTopGap: CGFloat = 14
    private static let pageFitBottomGap: CGFloat = 130
    // ScanView.dc.html lines 254 and 261: the strip's 44 pt ends 22 pt above the bottom bar's 56 (top 692 and 758 of
    // 844). The strip's glass bar reaches below its pages by its padding.
    private static let stripBarGap: CGFloat = 22 - PageStripTile.barPadding
    // ScanView.dc.html lines 254 and 367: a page at rest ends 12 pt above the strip (164 and 152 pt above the screen's
    // bottom edge). Above the default size the controls grow, and the page keeps that gap above them.
    private static let pageControlsGap: CGFloat = 12
    // ScanView.dc.html line 261 and Trash.dc.html line 167: the bottom bar is 20 pt in from the sides and 30 pt above
    // the screen's bottom edge.
    private static let barSideInset: CGFloat = 20
    private static let barBottomInset: CGFloat = 30
    // ScanDetails.dc.html lines 18 and 34: with Details up the page fits 8 pt above the panel.
    private static let pageSheetGap: CGFloat = 8

    /// The strip and bar's height, which grows with Dynamic Type.
    @State private var bottomControlsHeight: CGFloat = 0
    /// The pill's own height where it sits below the bar, nil until measured.
    @State private var belowBarHeaderHeight: CGFloat?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme

    public init(
        model: ViewerModel,
        pages: any PageImageProviding,
        thumbnails: any ThumbnailProviding,
        detailsHeight: CGFloat = 0,
        detailsProgress: CGFloat = 0,
        chromeProgress: CGFloat? = nil,
        onDetails: @escaping () -> Void = {},
        onDetailsDrag: @escaping (DetailsDrag) -> Void = { _ in },
        onRestored: @escaping () -> Void = {}
    ) {
        self.model = model
        self.pages = pages
        self.thumbnails = thumbnails
        self.detailsHeight = detailsHeight
        self.detailsProgress = detailsProgress
        self.chromeProgress = chromeProgress ?? detailsProgress
        self.onDetails = onDetails
        self.onDetailsDrag = onDetailsDrag
        self.onRestored = onRestored
    }

    public var body: some View {
        pager
            .background { Tokens.Color.bgGrouped.ignoresSafeArea() }
            .overlay(alignment: .bottom) {
                fadesForDetails(
                    bottomControls
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { bottomControlsHeight = $0 }
                        .padding(.bottom, Self.barBottomInset)
                        .ignoresSafeArea(edges: .bottom)
                        .environment(\.colorScheme, controlsScheme ?? colorScheme))
            }
            // The system bar, clear, like the grid's: the back button is the system's glass one and swipe back works,
            // except from Trash, which has Close and no swipe back.
            .toolbarBackground(.hidden, for: .navigationBar)
            // No large title, whatever pushed it: a large title's room would move the page's fit top.
            .toolbarTitleDisplayMode(.inline)
            .toolbarColorScheme(controlsScheme, for: .navigationBar)
            // Trash.dc.html line 163: Close rather than back, in the system's glass.
            .navigationBarBackButtonHidden(isFromTrash)
            .toolbar {
                if isFromTrash {
                    ToolbarItem(placement: .topBarLeading) { closeButton }
                }
                // Always in the bar, so it fades rather than blinking out (B2). Once Details is fully up the pill is
                // invisible and leaves: the bar doesn't pass a hidden pill's hiding on to VoiceOver.
                if !headerIsBelowTheBar {
                    ToolbarItem(placement: .principal) {
                        if !DetailsMotion.chromeIsHidden(progress: chromeProgress) {
                            header.frame(maxWidth: isFromTrash ? Self.trashHeaderMaxWidth : Self.headerMaxWidth)
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            // The bar can't hold the pill above the default text size, which wraps instead of cutting off (requirements 06 · Accessibility).
            // As Details rises it gives up its room, so the page grows into it, and it leaves once Details is up.
            .safeAreaInset(edge: .top) {
                if headerIsBelowTheBar && !DetailsMotion.chromeIsHidden(progress: chromeProgress) {
                    header.padding(.horizontal, Tokens.Spacing.s4)
                        .environment(\.colorScheme, controlsScheme ?? colorScheme)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { belowBarHeaderHeight = $0 }
                        .frame(
                            height: belowBarHeaderHeight.map {
                                DetailsMotion.chromeRoom(progress: detailsProgress, height: $0)
                            },
                            alignment: .top)
                }
            }
            .onChange(of: model.isMissing, initial: true) { _, isMissing in
                if isMissing { dismiss() }
            }
            .editAlert(model.editAlert, dismiss: model.dismissEditAlert)
            // Ready before the swipe: a page's first frame reads the cache.
            .task(id: model.currentPage) {
                for page in model.neighbouringPages {
                    guard !Task.isCancelled else { return }
                    _ = await pages.page(for: model.id, index: page)
                }
            }
    }

    /// A zoomed page fills the screen with paper, white in both appearances, so the glass controls over it take the
    /// light appearance: dark mode's white text would fade into glass over white (the strip's ring has the same reason).
    private var controlsScheme: ColorScheme? { model.isPageZoomed ? .light : nil }

    private var isFromTrash: Bool { model.mode == .trash }

    /// The panel shows the title, so the pill, strip and bar make way (07-01): they fade with Details (B2), stop taking
    /// taps past halfway and leave VoiceOver once it is up.
    private func fadesForDetails(_ chrome: some View) -> some View {
        chrome
            .opacity(DetailsMotion.chromeOpacity(progress: chromeProgress))
            .allowsHitTesting(DetailsMotion.chromeTakesTaps(progress: chromeProgress))
            .accessibilityHidden(DetailsMotion.chromeIsHidden(progress: chromeProgress))
    }

    /// The header wraps above the default size (see `header`), and the bar can't hold more than one line.
    private var headerIsBelowTheBar: Bool { typeSize > .large }

    /// Full screen, under the status bar and the glass controls, so a zoomed page fills it (P2). At rest each page still
    /// fits between the controls: the fit insets are the safe area plus the mock's gaps.
    private var pager: some View {
        GeometryReader { proxy in
            let fitInsets = UIEdgeInsets(
                top: proxy.safeAreaInsets.top + Self.pageFitTopGap,
                left: proxy.safeAreaInsets.leading,
                bottom: pageFitBottom(safeArea: proxy.safeAreaInsets.bottom),
                right: proxy.safeAreaInsets.trailing)
            Pager(count: model.pageCount, selection: $model.currentPage) { page in
                ZoomablePage(
                    id: model.id,
                    index: page,
                    isCurrent: page == model.currentPage,
                    // Only these three may hold a full-size image, however far a long scan is swiped.
                    holdsImage: model.holdsPage(page),
                    label: model.pageImageLabel(page),
                    fitInsets: fitInsets,
                    provider: pages
                ) { isZoomed in
                    if page == model.currentPage { model.isPageZoomed = isZoomed }
                }
            }
            // Only a mostly upward drag on a page at rest, and never from Trash, where a scan is read-only (Plan 2's E6).
            .gesture(
                DetailsSwipe(
                    begins: {
                        DetailsMotion.swipeOpens(
                            translation: $0, isPageZoomed: model.isPageZoomed, isFromTrash: isFromTrash)
                    },
                    onDrag: onDetailsDrag)
            )
            .ignoresSafeArea()
        }
    }

    /// Above the bar at rest and above the Details panel while it is up, moving between the two with Details.
    private func pageFitBottom(safeArea: CGFloat) -> CGFloat {
        DetailsMotion.pageFitBottom(
            progress: detailsProgress,
            closed: max(
                safeArea + Self.pageFitBottomGap, Self.barBottomInset + bottomControlsHeight + Self.pageControlsGap),
            travel: DetailsMotion.travel(panelHeight: detailsHeight, inset: DetailsPanel.inset),
            gap: Self.pageSheetGap)
    }

    /// The page strip (with more than one page) above the bottom bar.
    private var bottomControls: some View {
        VStack(spacing: Self.stripBarGap) {
            if model.showsStrip {
                ViewerPageStrip(
                    id: model.id,
                    pageCount: model.pageCount,
                    currentPage: $model.currentPage,
                    label: model.pageLabel,
                    thumbnails: thumbnails
                )
                .padding(.horizontal, Tokens.Spacing.s4)
            }
            Group {
                switch model.mode {
                case .library:
                    ViewerBottomBar(onDetails: onDetails, trashMessage: model.trashMessage, onTrash: moveToTrash)
                case .trash:
                    TrashViewerChrome(model: model, onRestored: onRestored)
                }
            }
            .padding(.horizontal, Self.barSideInset)
        }
    }

    /// Trash's confirmed move: the view pops as the scan leaves the library.
    private func moveToTrash() {
        if model.moveToTrash() { MovedToTrash.announce() }
    }

    /// Back to Trash.
    private var closeButton: some View {
        Button(
            action: { dismiss() },
            label: { Image(systemName: "xmark") }
        )
        .accessibilityLabel(Text("Close", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.TrashViewer.close)
    }

    @ViewBuilder
    private var header: some View {
        switch model.mode {
        case .library: fadesForDetails(libraryHeader)
        case .trash: trashHeader
        }
    }

    /// The title over the days left in Trash (09-04). It opens nothing: Details edits a library scan.
    private var trashHeader: some View {
        PagePill(title: Text(model.title), identifier: AccessibilityID.TrashViewer.header, shape: headerShape) {
            timeLeft
        }
        .lineLimit(typeSize <= .large ? 1 : nil)
        .accessibilityLabel(Text(model.title))
        .accessibilityValue(Text(model.timeLeftText))
    }

    /// A button that opens Details (M13).
    private var libraryHeader: some View {
        Button(action: onDetails) {
            PagePill(title: Text(model.title), identifier: AccessibilityID.Viewer.header, shape: headerShape) {
                // At large text the line wraps, and the dot stays with its first line.
                HStack(alignment: headerIsBelowTheBar ? .firstTextBaseline : .center, spacing: Self.dotGap) {
                    if let collection = model.collection { CollectionDot(collection: collection) }
                    Text("\(model.collectionName) · \(timeLeft)", bundle: #bundle)
                }
            }
            // ScanView.dc.html line 222: one line with an ellipsis; above the default size it wraps rather than cutting
            // off.
            .lineLimit(typeSize <= .large ? 1 : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(model.title), details", bundle: #bundle))
        .accessibilityValue(Text("\(model.collectionName) · \(model.timeLeftText)", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.Viewer.header)
    }

    /// A scan's own title can wrap to many lines at large text, where a capsule's ends would cut into it.
    private var headerShape: AnyShape {
        headerIsBelowTheBar ? AnyShape(.rect(cornerRadius: Tokens.Radius.surface)) : AnyShape(.capsule)
    }

    /// Only a soon expiry colours its own run. Otherwise the run takes the pill's detail colour, which is the primary
    /// colour in dark mode (Ben, 2026-11-07): a colour set here would override it.
    private var timeLeft: Text {
        let text = Text(model.timeLeftText)
        return model.isSoon ? text.fontWeight(.semibold).foregroundStyle(Tokens.Color.expirySoon) : text
    }
}
