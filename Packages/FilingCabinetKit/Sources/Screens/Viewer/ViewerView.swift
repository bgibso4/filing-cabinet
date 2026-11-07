import Core
import Library
import ScreenModels
import SwiftUI

/// A scan, like Photos: its pages, a back button, a header pill and the page strip. Per A2 there is no More button and
/// no bottom bar yet.
public struct ViewerView: View {
    @Bindable private var model: ViewerModel
    private let pages: any PageImageProviding
    private let thumbnails: any ThumbnailProviding

    // ScanView.dc.html line 221: the pill is at most 240 pt wide.
    private static let headerMaxWidth: CGFloat = 240
    // ScanView.dc.html line 223: 5 pt between the dot and the text.
    private static let dotGap: CGFloat = 5
    // ScanView.dc.html lines 367-368: at rest a page fits from 14 pt under the header's row (top 120, the row ending at
    // 106) to 164 pt above the screen's bottom edge (120 + 560 of 844), 34 of them the safe area. Measured from the safe
    // area, which holds the bar.
    private static let pageFitTopGap: CGFloat = 14
    private static let pageFitBottomGap: CGFloat = 130
    // ScanView.dc.html line 254: the strip's 44 pt ends 108 pt above the screen's bottom edge (top 692 of 844), 34 of
    // them the safe area. The strip's glass bar reaches below its pages by its padding.
    private static let stripBottomGap: CGFloat = 74 - PageStripTile.barPadding

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme

    public init(
        model: ViewerModel,
        pages: any PageImageProviding,
        thumbnails: any ThumbnailProviding
    ) {
        self.model = model
        self.pages = pages
        self.thumbnails = thumbnails
    }

    public var body: some View {
        pager
            .background { Tokens.Color.bgGrouped.ignoresSafeArea() }
            .overlay(alignment: .bottom) {
                if model.showsStrip {
                    ViewerPageStrip(
                        id: model.id,
                        pageCount: model.pageCount,
                        currentPage: $model.currentPage,
                        label: model.pageLabel,
                        thumbnails: thumbnails
                    )
                    .padding(.horizontal, Tokens.Spacing.s4)
                    .padding(.bottom, Self.stripBottomGap)
                    .environment(\.colorScheme, controlsScheme ?? colorScheme)
                }
            }
            // The system bar, clear, like the grid's: the back button is the system's glass one and swipe back works.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(controlsScheme, for: .navigationBar)
            .toolbar {
                if !headerIsBelowTheBar {
                    ToolbarItem(placement: .principal) {
                        header.frame(maxWidth: Self.headerMaxWidth)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            // The bar can't hold the pill above the default text size, which wraps instead of cutting off (requirements 06 · Accessibility).
            .safeAreaInset(edge: .top) {
                if headerIsBelowTheBar {
                    header.padding(.horizontal, Tokens.Spacing.s4)
                        .environment(\.colorScheme, controlsScheme ?? colorScheme)
                }
            }
            .onChange(of: model.isMissing, initial: true) { _, isMissing in
                if isMissing { dismiss() }
            }
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

    /// The header wraps above the default size (see `header`), and the bar can't hold more than one line.
    private var headerIsBelowTheBar: Bool { typeSize > .large }

    /// Full screen, under the status bar and the glass controls, so a zoomed page fills it (P2). At rest each page still
    /// fits between the controls: the fit insets are the safe area plus the mock's gaps.
    private var pager: some View {
        GeometryReader { proxy in
            let fitInsets = UIEdgeInsets(
                top: proxy.safeAreaInsets.top + Self.pageFitTopGap,
                left: proxy.safeAreaInsets.leading,
                bottom: proxy.safeAreaInsets.bottom + Self.pageFitBottomGap,
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

    private var header: some View {
        PagePill(title: Text(model.title), identifier: AccessibilityID.Viewer.header, shape: headerShape) {
            // At large text the line wraps, and the dot stays with its first line.
            HStack(alignment: headerIsBelowTheBar ? .firstTextBaseline : .center, spacing: Self.dotGap) {
                if let collection = model.collection { CollectionDot(collection: collection) }
                Text("\(model.collectionName) · \(timeLeft)", bundle: #bundle)
            }
        }
        // ScanView.dc.html line 222: one line with an ellipsis; above the default size it wraps rather than cutting off.
        .lineLimit(typeSize <= .large ? 1 : nil)
        .accessibilityAddTraits(.isHeader)
    }

    /// A scan's own title can wrap to many lines at large text, where a capsule's ends would cut into it.
    private var headerShape: AnyShape {
        headerIsBelowTheBar ? AnyShape(.rect(cornerRadius: Tokens.Radius.surface)) : AnyShape(.capsule)
    }

    private var timeLeft: Text {
        Text(model.timeLeftText)
            .fontWeight(model.isSoon ? .semibold : .regular)
            .foregroundStyle(model.isSoon ? Tokens.Color.expirySoon : Tokens.Color.textSecondary)
    }
}
