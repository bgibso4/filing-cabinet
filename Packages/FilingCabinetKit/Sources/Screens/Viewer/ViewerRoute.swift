import Library
import ScreenModels
import SwiftUI

/// The viewer as a navigation destination, with the Details panel it opens. The stack evaluates its destination again
/// whenever the root changes, so the model is kept here for as long as the destination lives; a new one would send the
/// viewer back to the first page.
///
/// One spring moves Details (M3): its position is the progress that places the panel, fits the page and fades the
/// chrome, every frame (E2). Open and close retarget it; a drag (a swipe up on the page, or on the panel) holds it under
/// the finger and releases it with the finger's speed.
public struct ViewerRoute: View {
    private static let closed = DetailsSpring(position: 0, velocity: 0, target: 0)

    private let makeDetails: () -> DetailsModel
    private let pages: any PageImageProviding
    private let thumbnails: any ThumbnailProviding
    private let onRestored: () -> Void
    @State private var model: ViewerModel
    /// Made each time Details opens, so it starts without an Undo from last time; let go once it has closed.
    @State private var details: DetailsModel?
    @State private var detailsHeight: CGFloat = 0
    @State private var spring = Self.closed
    /// Where the spring was when the drag began.
    @State private var dragStart: CGFloat = 0

    @Environment(\.reducesMotion) private var reducesMotion

    public init(
        makeModel: () -> ViewerModel,
        makeDetails: @escaping () -> DetailsModel,
        pages: any PageImageProviding,
        thumbnails: any ThumbnailProviding,
        onRestored: @escaping () -> Void = {}
    ) {
        self.makeDetails = makeDetails
        self.pages = pages
        self.thumbnails = thumbnails
        self.onRestored = onRestored
        model = makeModel()
    }

    public var body: some View {
        ViewerView(
            model: model,
            pages: pages,
            thumbnails: thumbnails,
            detailsHeight: detailsHeight,
            detailsProgress: progress,
            chromeProgress: spring.position,
            onDetails: open,
            onDetailsDrag: drag,
            onRestored: onRestored
        )
        .overlay(alignment: .bottom) {
            if let details {
                DetailsPanel(
                    model: details, progress: panelProgress, height: $detailsHeight, onDrag: drag, onClose: close
                )
                .opacity(DetailsMotion.panelOpacity(progress: spring.position, reducesMotion: reducesMotion))
            }
        }
        .background { springDriver }
        .onAppear { model.appeared() }
        // Once the scan leaves the library (Trash, or midnight passing its last day) the panel closes as the viewer
        // pops (Review Focus 2).
        .onChange(of: details?.isMissing ?? false) { _, isMissing in
            if isMissing {
                details = nil
                spring = Self.closed
            }
        }
    }

    /// Where the page is: the spring's position, or its target under Reduce Motion (B11).
    private var progress: CGFloat {
        DetailsMotion.layoutProgress(position: spring.position, target: spring.target, reducesMotion: reducesMotion)
    }

    /// Where the panel is: the spring's position, or under Reduce Motion open, or where a close began while it fades.
    private var panelProgress: CGFloat {
        DetailsMotion.panelProgress(
            position: spring.position, target: spring.target, origin: spring.origin, reducesMotion: reducesMotion)
    }

    /// The panel's travel from fully up to fully below the screen, unknown (0) until the panel is measured.
    private var travel: CGFloat { DetailsMotion.travel(panelHeight: detailsHeight, inset: DetailsPanel.inset) }

    /// Steps the spring once a frame while it moves, and not at all at rest or under a finger.
    private var springDriver: some View {
        TimelineView(.animation(paused: spring.isSettled)) { context in
            Color.clear.onChange(of: context.date) { previous, now in
                spring.step(by: now.timeIntervalSince(previous))
                letGoIfClosed()
            }
        }
    }

    private func open() {
        if details == nil { details = makeDetails() }
        spring.target = 1
    }

    private func close() {
        spring.target = 0
    }

    private func drag(_ phase: DetailsDrag) {
        switch phase {
        case .began:
            // A swipe up on the page can start with Details closed.
            if details == nil { details = makeDetails() }
            dragStart = spring.position
            spring.hold(at: spring.position)
        case .changed(let translation):
            spring.hold(at: DetailsMotion.progress(dragStart: dragStart, translation: translation, travel: travel))
        case .ended(let velocity):
            spring.release(velocity: DetailsMotion.progressVelocity(pointsPerSecond: velocity, travel: travel))
            letGoIfClosed()
        }
    }

    private func letGoIfClosed() {
        if spring.isClosed, details != nil { details = nil }
    }
}
