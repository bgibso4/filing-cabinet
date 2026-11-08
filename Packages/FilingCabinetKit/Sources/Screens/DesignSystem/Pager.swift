import SwiftUI

/// Pages side by side, paged like Photos: the page follows the finger, a flick glides on to the next page and a slow
/// drag goes on past half way or springs back. One paging scroll view does all of it, so nothing here decides where a
/// swipe lands. `selection` moves the scroll when set from outside, and follows it once the scroll comes to rest: a
/// drag past half way and back never changes the page, so a zoomed page stays zoomed.
///
/// Every page keeps its identity for as long as the pager lives: changing what a page shows never replaces the view, so
/// nothing is rebuilt under a swipe that is still moving.
struct Pager<Page: View>: View {
    let count: Int
    @Binding var selection: Int
    @ViewBuilder let page: (Int) -> Page

    /// The page the scroll is on, updated as it moves; nil between pages.
    @State private var position: Int?

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
        .scrollPosition(id: $position)
        .onScrollPhaseChange { _, phase in
            if phase == .idle, let position, position != selection { selection = position }
        }
        .onChange(of: selection, initial: true) { _, page in
            if page != position { position = page }
        }
    }
}
