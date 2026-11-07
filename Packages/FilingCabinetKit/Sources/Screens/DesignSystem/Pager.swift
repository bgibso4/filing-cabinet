import SwiftUI

/// Pages side by side, paged like Photos: the page follows the finger, a flick glides on to the next page and a slow
/// drag goes on past half way or springs back. One paging scroll view does all of it, so nothing here decides where a
/// swipe lands. `selection` follows the scroll and moves it when set from outside.
///
/// Every page keeps its identity for as long as the pager lives: changing what a page shows never replaces the view, so
/// nothing is rebuilt under a swipe that is still moving.
struct Pager<Page: View>: View {
    let count: Int
    @Binding var selection: Int
    @ViewBuilder let page: (Int) -> Page

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    page(index)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        // A page is a picture: glass controls float over it rather than fading it out where they sit.
        .scrollEdgeEffectHidden(true, for: .all)
        .scrollPosition(id: position)
    }

    /// The scroll position's id is optional; between pages it can be nil, which leaves the selection where it was.
    private var position: Binding<Int?> {
        Binding(
            get: { selection },
            set: { page in
                if let page, page != selection { selection = page }
            })
    }
}
