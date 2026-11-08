import Core
import Library
import ScreenModels
import SwiftUI

/// A scan, like Photos: its pages, a back button, a header pill, the page strip and the bottom bar. Per A2 there is no
/// More button. The pill and Info open Details; while it is up (`detailsHeight`) the pill, strip and bar make way and
/// the page fits above the sheet (07-01).
public struct ViewerView: View {
    @Bindable private var model: ViewerModel
    private let pages: any PageImageProviding
    private let thumbnails: any ThumbnailProviding
    /// The Details sheet's height while it is up, nil while it is closed.
    private let detailsHeight: CGFloat?
    private let onDetails: () -> Void

    // ScanView.dc.html line 221: the pill is at most 240 pt wide.
    private static let headerMaxWidth: CGFloat = 240
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
    // ScanView.dc.html line 261: the bottom bar is 20 pt in from the sides and 30 pt above the screen's bottom edge.
    private static let barSideInset: CGFloat = 20
    private static let barBottomInset: CGFloat = 30
    // ScanDetails.dc.html lines 18 and 34: with Details up the page fits above the sheet, which floats 8 pt above the
    // screen's bottom edge, with 8 pt between them.
    private static let sheetBottomInset: CGFloat = 8
    private static let pageSheetGap: CGFloat = 8

    /// The strip and bar's height, which grows with Dynamic Type.
    @State private var bottomControlsHeight: CGFloat = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme

    public init(
        model: ViewerModel,
        pages: any PageImageProviding,
        thumbnails: any ThumbnailProviding,
        detailsHeight: CGFloat? = nil,
        onDetails: @escaping () -> Void = {}
    ) {
        self.model = model
        self.pages = pages
        self.thumbnails = thumbnails
        self.detailsHeight = detailsHeight
        self.onDetails = onDetails
    }

    public var body: some View {
        pager
            .background { Tokens.Color.bgGrouped.ignoresSafeArea() }
            .overlay(alignment: .bottom) {
                if !isShowingDetails {
                    bottomControls
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { bottomControlsHeight = $0 }
                        .padding(.bottom, Self.barBottomInset)
                        .ignoresSafeArea(edges: .bottom)
                        .environment(\.colorScheme, controlsScheme ?? colorScheme)
                }
            }
            // The system bar, clear, like the grid's: the back button is the system's glass one and swipe back works.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(controlsScheme, for: .navigationBar)
            .toolbar {
                if !headerIsBelowTheBar && !isShowingDetails {
                    ToolbarItem(placement: .principal) {
                        header.frame(maxWidth: Self.headerMaxWidth)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            // The bar can't hold the pill above the default text size, which wraps instead of cutting off (requirements 06 · Accessibility).
            .safeAreaInset(edge: .top) {
                if headerIsBelowTheBar && !isShowingDetails {
                    header.padding(.horizontal, Tokens.Spacing.s4)
                        .environment(\.colorScheme, controlsScheme ?? colorScheme)
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

    /// The sheet shows the title, so the pill makes way (07-01).
    private var isShowingDetails: Bool { detailsHeight != nil }

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
            .ignoresSafeArea()
        }
    }

    /// Above the bar at rest, or above the Details sheet while it is up.
    private func pageFitBottom(safeArea: CGFloat) -> CGFloat {
        guard let detailsHeight else {
            return max(
                safeArea + Self.pageFitBottomGap, Self.barBottomInset + bottomControlsHeight + Self.pageControlsGap)
        }
        return Self.sheetBottomInset + detailsHeight + Self.pageSheetGap
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
            ViewerBottomBar(onDetails: onDetails, trashMessage: model.trashMessage, onTrash: moveToTrash)
                .padding(.horizontal, Self.barSideInset)
        }
    }

    /// Trash's confirmed move: the view pops as the scan leaves the library.
    private func moveToTrash() {
        if model.moveToTrash() { MovedToTrash.announce() }
    }

    /// A button that opens Details (M13).
    private var header: some View {
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
