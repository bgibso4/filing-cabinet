import Core
import Library
import ScreenModels
import SwiftUI

/// Search over Home (B17): an opaque screen in a full-screen cover, which slides up from the bottom and back down on its
/// X with the cover's own slide (round 2: nothing of Home shows through). With Reduce Motion the root puts the cover up
/// and takes it down without the slide, and Search cross-fades in and out by itself. Its own stack pushes the viewer
/// from a result, so back returns to the results with the query kept (E1).
struct SearchCover<Viewer: View>: View {
    let makeModel: () -> SearchModel
    let thumbnails: any ThumbnailProviding
    let viewer: (ScanID) -> Viewer
    /// True with Reduce Motion: Search fades itself in and out over a clear cover.
    let fades: Bool
    /// A change closes Search as its X does: a request from outside the app needs it out of the way.
    let closes: Int
    /// Ends the cover: at once when it slides, after the fade when it fades.
    let onClosed: () -> Void

    // CaptureContainer's Reduce Motion fade (Task 20 Part C). No motion tokens exist in design/tokens.json.
    private static var fade: Animation { .easeOut(duration: 0.2) }

    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [ScanID] = []
    /// While fading: false before Search has faded in and once its X is tapped.
    @State private var isShown = false
    /// While fading: true from the X until Search has gone; it closes once, by the fade's completion or, if
    /// backgrounding interrupted it, on becoming active again (as CaptureContainer's layer does).
    @State private var isLeaving = false

    var body: some View {
        content.onChange(of: closes) { close() }
    }

    @ViewBuilder
    private var content: some View {
        if fades {
            screen
                .opacity(isShown ? 1 : 0)
                .allowsHitTesting(isShown)
                .onAppear {
                    withAnimation(Self.fade) { isShown = true }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, isLeaving { finishLeaving() }
                }
        } else {
            screen
        }
    }

    private var screen: some View {
        NavigationStack(path: $path) {
            GridRoute(makeModel: makeModel) { model in
                SearchView(model: model, thumbnails: thumbnails, onOpen: { path.append($0) }, onClose: close)
            }
            .navigationDestination(for: ScanID.self) { viewer($0) }
        }
        // Opaque under every screen of the stack, so nothing of Home shows through.
        .background(Tokens.Color.bgGrouped)
    }

    private func close() {
        guard fades else { return onClosed() }
        guard !isLeaving else { return }
        isLeaving = true
        withAnimation(Self.fade) {
            isShown = false
        } completion: {
            finishLeaving()
        }
    }

    private func finishLeaving() {
        guard isLeaving else { return }
        isLeaving = false
        var cut = Transaction()
        cut.disablesAnimations = true
        withTransaction(cut, onClosed)
    }
}
