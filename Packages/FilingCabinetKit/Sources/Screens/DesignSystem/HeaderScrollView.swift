import ScreenModels
import SwiftUI

/// A screen's scroll view under its Passwords-style header (#62): the system bar, with the title in our serif in both
/// sizes (`HeaderTitle`). Inner screens rest with the title small in the bar; pulling past halfway brings out the large
/// title, which stays until a scroll up collapses it (B6, UIKit's own snap). Screens keep their own toolbar items.
struct HeaderScrollView<Content: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let identifier: String
    private let rest: HeaderRest
    private let scrolls: Bool
    private let content: Content

    @State private var position = ScrollPosition(y: 0)
    @State private var insets = HeaderInsets()
    @State private var rested = false

    init(
        title: Text,
        subtitle: Text?,
        identifier: String,
        rest: HeaderRest,
        scrolls: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.identifier = identifier
        self.rest = rest
        self.scrolls = scrolls
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                ZStack(alignment: .top) {
                    // M8 on an outer layer, with the content at its ideal height: the stack proposes its full height to
                    // its children, which would stretch flexible rows.
                    Color.clear.frame(height: minimumContentHeight(proxy))
                    content.fixedSize(horizontal: false, vertical: true)
                }
            }
            .scrollPosition($position)
            .scrollDisabled(!scrolls)
            .onScrollGeometryChange(for: CGFloat.self, of: \.contentInsets.top) { _, inset in arrive(inset) }
        }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.large)
        // Clear, so the back button is the system's glass one and swipe back works (hiding the bar turns it off).
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            HeaderTitle(title: title, subtitle: subtitle, identifier: identifier, growth: growth)
        }
    }

    private var growth: CGFloat { insets.growth(resting: rest) }

    private func minimumContentHeight(_ proxy: GeometryProxy) -> CGFloat {
        scrolls ? insets.minimumContentHeight(height: proxy.size.height + proxy.safeAreaInsets.top) : 0
    }

    /// The bar opens with the large title showing. To rest small, the content scrolls by the bar's inset (more than the
    /// large title) so the bar collapses, then back to its top once it has: the scroll position keeps its offset across
    /// the bar's change, which would leave the first rows under the bar (E1). UIKit's own snap does the rest (B6).
    private func arrive(_ inset: CGFloat) {
        guard inset > 0 else { return }
        let first = insets == HeaderInsets()
        insets.record(inset)
        guard rest == .small, scrolls, !rested else { return }
        if first {
            position.scrollTo(y: inset)
        } else if insets.hasCollapsed {
            rested = true
            position.scrollTo(y: 0)
        }
    }
}
