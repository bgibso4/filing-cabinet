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
    // ScanView.dc.html lines 367-368: a page fits from 14 pt under the header's row (top 120, the row ending at 106) to
    // 164 pt above the screen's bottom edge (120 + 560 of 844), 34 of them the safe area.
    private static let pageFitInsets = UIEdgeInsets(top: 14, left: 0, bottom: 130, right: 0)
    // ScanView.dc.html line 254: the strip's 44 pt ends 108 pt above the screen's bottom edge (top 692 of 844), 34 of
    // them the safe area.
    private static let stripBottomGap: CGFloat = 74

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

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
                        currentPage: model.currentPage,
                        label: model.pageLabel,
                        thumbnails: thumbnails
                    )
                    .padding(.bottom, Self.stripBottomGap)
                }
            }
            // The system bar, clear, like the grid's: the back button is the system's glass one and swipe back works.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !headerIsBelowTheBar {
                    ToolbarItem(placement: .principal) {
                        header.frame(maxWidth: Self.headerMaxWidth)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            // The bar can't hold the pill at large text, which wraps instead of cutting off (requirements 06 · Accessibility).
            .safeAreaInset(edge: .top) {
                if headerIsBelowTheBar {
                    header.padding(.horizontal, Tokens.Spacing.s4)
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

    private var headerIsBelowTheBar: Bool { typeSize.isAccessibilitySize }

    private var pager: some View {
        TabView(selection: $model.currentPage) {
            ForEach(0..<model.pageCount, id: \.self) { page in
                Group {
                    // A paged TabView can keep every page it has shown; only these three may hold a full-size image.
                    if model.holdsPage(page) {
                        ZoomablePage(
                            id: model.id,
                            index: page,
                            isCurrent: page == model.currentPage,
                            label: model.pageImageLabel(page),
                            fitInsets: Self.pageFitInsets,
                            provider: pages
                        )
                    } else {
                        Color.clear
                    }
                }
                .tag(page)
            }
        }
        // Stays inside the safe area: a page TabView that ignores it draws its pages off centre by half the difference
        // between the top and bottom insets (41 pt under this bar). So a zoomed page stops at the bar.
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var header: some View {
        PagePill(title: Text(model.title), identifier: AccessibilityID.Viewer.header, shape: headerShape) {
            // At large text the line wraps, and the dot stays with its first line.
            HStack(alignment: typeSize.isAccessibilitySize ? .firstTextBaseline : .center, spacing: Self.dotGap) {
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
