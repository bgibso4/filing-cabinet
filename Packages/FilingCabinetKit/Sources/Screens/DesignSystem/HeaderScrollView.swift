import ScreenModels
import SwiftUI

/// A screen's scroll view under its Passwords-style header (#62): the system bar's own title and subtitle (plan 3, E9),
/// in our serif (`HeaderAppearance`), the large subtitle in the design's size (`LargeSubtitle`). Inner screens rest with the title small in the bar; pulling past halfway brings out the large
/// title, which stays until a scroll up collapses it (B6, UIKit's own snap). Screens keep their own toolbar items.
///
/// Keep one `HeaderScrollView` for a screen and change `rest` and `scrolls` on it as its content changes (an empty
/// Trash filling up, a grid emptying): it settles again from where the bar is (`HeaderSettling`), collapsing the bar
/// for small or expanding it for large. Don't swap in a new one (`if`/`else` or `.id`) under a collapsed bar: it can't
/// tell that bar from an expanded one, and would rest scrolled under it.
struct HeaderScrollView<Content: View>: View {
    private let title: Text
    private let subtitle: String?
    private let rest: HeaderRest
    private let scrolls: Bool
    private let content: Content

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var position = ScrollPosition(y: 0)
    @State private var insets = HeaderInsets()
    @State private var settling: HeaderSettling
    @State private var last = LastInset()
    @State private var offsetRequest: ScrollViewOffset.Request?

    init(
        title: Text,
        subtitle: String?,
        rest: HeaderRest,
        scrolls: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.rest = rest
        self.scrolls = scrolls
        self.content = content()
        _settling = State(initialValue: HeaderSettling(rest: rest, scrolls: scrolls))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                ZStack(alignment: .top) {
                    // M8 on an outer layer, with the content at its ideal height: the stack proposes its full height to
                    // its children, which would stretch flexible rows. Content that doesn't scroll (an empty state)
                    // gets the whole height the header leaves instead, to centre itself in.
                    Color.clear.frame(height: minimumContentHeight(proxy))
                    content
                        .fixedSize(horizontal: false, vertical: scrolls)
                        .frame(minHeight: scrolls ? nil : proxy.size.height, alignment: .top)
                }
                .background(ScrollViewOffset(request: offsetRequest))
            }
            .scrollPosition($position)
            .scrollDisabled(!scrolls)
            .onScrollGeometryChange(for: BarReport.self, of: BarReport.init) { _, report in arrive(report) }
            // A touch, not our own animated expand (`.animating`): from now on the bar is the person's.
            .onScrollPhaseChange { _, phase in
                if phase == .tracking || phase == .interacting { settling.stopWatching() }
            }
        }
        // Covered by a pushed screen, whose bar this one shares.
        .onDisappear { settling.stopWatching() }
        .onChange(of: [rest == .small, scrolls]) {
            settling.update(rest: rest, scrolls: scrolls)
            if let inset = last.inset { settle(inset) }
        }
        .navigationTitle(title)
        .modifier(Subtitle(subtitle: subtitle))
        .toolbarTitleDisplayMode(.large)
    }

    private func minimumContentHeight(_ proxy: GeometryProxy) -> CGFloat {
        scrolls ? insets.minimumContentHeight(height: proxy.size.height + proxy.safeAreaInsets.top) : 0
    }

    private func arrive(_ report: BarReport) {
        insets.largeTitleHeight = HeaderAppearance.largeTitleHeight(at: typeSize)
        insets.record(report.inset, atTop: report.atTop)
        last.inset = report.inset
        settle(report.inset)
    }

    private func settle(_ inset: CGFloat) {
        switch settling.target(insets: insets, inset: inset) {
        case .content(let offset): position.scrollTo(y: offset)
        case .scrollView(let offset): request(offset, duringPush: false)
        case .pullDuringPush(let offset): request(offset, duringPush: true)
        case nil: break
        }
    }

    private func request(_ offset: CGFloat, duringPush: Bool) {
        offsetRequest = .init(offset: offset, duringPush: duringPush, count: (offsetRequest?.count ?? 0) + 1)
    }
}

/// The system bar's subtitle, under the title in both sizes. The bar draws the large one with the small one's attributes
/// (it ignores `largeSubtitleTextAttributes`, and a styled `Text` in `navigationSubtitle`), so the large one is also set
/// as the navigation item's large attributed subtitle, in the design's subheadline (`LargeSubtitle`).
private struct Subtitle: ViewModifier {
    let subtitle: String?

    func body(content: Content) -> some View {
        if let subtitle {
            content
                .navigationSubtitle(Text(subtitle))
                .background(LargeSubtitle(text: subtitle))
        } else {
            content
        }
    }
}

/// What the header follows of the scroll: the bar's inset, and whether the content is at its top. Not the offset itself,
/// so the screen doesn't update on every frame of a scroll under a collapsed bar.
private struct BarReport: Equatable {
    let inset: CGFloat
    let atTop: Bool

    init(_ geometry: ScrollGeometry) {
        inset = geometry.contentInsets.top
        atTop = HeaderInsets.isAtTop(inset: inset, contentOffset: geometry.contentOffset.y)
    }
}

/// Holds the last inset without SwiftUI observing it: it is read only when `rest` or `scrolls` changes.
private final class LastInset {
    var inset: CGFloat?
}
