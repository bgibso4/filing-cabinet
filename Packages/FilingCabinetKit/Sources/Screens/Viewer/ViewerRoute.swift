import Library
import ScreenModels
import SwiftUI

/// The viewer as a navigation destination, with the Details sheet it opens. The stack evaluates its destination again
/// whenever the root changes, so the model is kept here for as long as the destination lives; a new one would send the
/// viewer back to the first page.
public struct ViewerRoute: View {
    private let makeDetails: () -> DetailsModel
    private let pages: any PageImageProviding
    private let thumbnails: any ThumbnailProviding
    @State private var model: ViewerModel
    /// Made each time Details opens, so it starts without an Undo from last time.
    @State private var details: DetailsModel?
    @State private var detailsHeight: CGFloat = 0

    public init(
        makeModel: () -> ViewerModel,
        makeDetails: @escaping () -> DetailsModel,
        pages: any PageImageProviding,
        thumbnails: any ThumbnailProviding
    ) {
        self.makeDetails = makeDetails
        self.pages = pages
        self.thumbnails = thumbnails
        model = makeModel()
    }

    public var body: some View {
        ViewerView(
            model: model,
            pages: pages,
            thumbnails: thumbnails,
            detailsHeight: details == nil ? nil : detailsHeight,
            onDetails: { details = makeDetails() }
        )
        .sheet(isPresented: isShowingDetails) {
            if let details { DetailsSheet(model: details, height: $detailsHeight) }
        }
        // Once the scan leaves the library (Trash, or midnight passing its last day) the sheet closes as the viewer
        // pops (Review Focus 2).
        .onChange(of: details?.isMissing ?? false) { _, isMissing in
            if isMissing { details = nil }
        }
    }

    private var isShowingDetails: Binding<Bool> {
        Binding(
            get: { details != nil },
            set: { isShowing in
                if !isShowing { details = nil }
            })
    }
}
