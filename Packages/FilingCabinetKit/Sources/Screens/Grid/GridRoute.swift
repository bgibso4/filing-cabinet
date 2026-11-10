import SwiftUI

/// A grid (a collection, Recent, All Scans or Trash), a Settings screen or Search as a navigation destination (#56). The stack
/// evaluates its destination again whenever the root changes, so the model is kept here for as long as the destination
/// lives, as `ViewerRoute` keeps the viewer's: a new one would drop what the screen was doing, such as Trash's selection
/// or a lifespan change waiting on its confirmation.
struct GridRoute<Model, Content: View>: View {
    @State private var model: Model
    private let content: (Model) -> Content

    init(makeModel: () -> Model, @ViewBuilder content: @escaping (Model) -> Content) {
        model = makeModel()
        self.content = content
    }

    var body: some View {
        content(model)
    }
}
