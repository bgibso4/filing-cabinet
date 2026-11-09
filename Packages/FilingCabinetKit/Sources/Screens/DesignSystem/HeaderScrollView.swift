import ScreenModels
import SwiftUI

/// A screen's scroll view under its Passwords-style header (#62): the system bar, with the title in our serif in both
/// sizes (`HeaderTitle`). Inner screens rest with the title small in the bar; pulling past halfway brings out the large
/// title, which stays until a scroll up collapses it (B6, UIKit's own snap). Screens keep their own toolbar items.
///
/// Keep one `HeaderScrollView` for a screen and change `rest` and `scrolls` on it as its content changes (an empty
/// Trash filling up): resting small settles again from where the bar is (`HeaderSettling`). Don't swap in a new one
/// (`if`/`else` or `.id`) under a collapsed bar: it can't tell that bar from an expanded one, and would rest scrolled
/// under it.
struct HeaderScrollView<Content: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let identifier: String
    private let rest: HeaderRest
    private let scrolls: Bool
    private let content: Content

    @State private var position = ScrollPosition(y: 0)
    @State private var insets = HeaderInsets()
    @State private var settling: HeaderSettling
    @State private var last = LastInset()

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
        _settling = State(initialValue: HeaderSettling(rest: rest, scrolls: scrolls))
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
        .onChange(of: [rest == .small, scrolls]) {
            settling.update(rest: rest, scrolls: scrolls)
            if let inset = last.inset { settle(inset) }
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

    private func arrive(_ inset: CGFloat) {
        insets.record(inset)
        last.inset = inset
        settle(inset)
    }

    private func settle(_ inset: CGFloat) {
        if let target = settling.target(insets: insets, inset: inset) { position.scrollTo(y: target) }
    }
}

/// Holds the last inset without SwiftUI observing it: it is read only when `rest` or `scrolls` changes.
private final class LastInset {
    var inset: CGFloat?
}
