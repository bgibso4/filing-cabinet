import Library
import ScreenModels
import SwiftUI

/// The viewer as a navigation destination. The stack evaluates its destination again whenever the root changes, so the
/// model is kept here for as long as the destination lives; a new one would send the viewer back to the first page.
public struct ViewerRoute: View {
    private let pages: any PageImageProviding
    private let thumbnails: any ThumbnailProviding
    @State private var model: ViewerModel

    public init(
        makeModel: () -> ViewerModel,
        pages: any PageImageProviding,
        thumbnails: any ThumbnailProviding
    ) {
        self.pages = pages
        self.thumbnails = thumbnails
        model = makeModel()
    }

    public var body: some View {
        ViewerView(model: model, pages: pages, thumbnails: thumbnails)
    }
}
