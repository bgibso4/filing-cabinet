import Core
import Library
import ScreenModels
import SwiftUI

/// Search over Home (B17): it rises from the bottom while fading in, so Home fades out behind it, and closes the same
/// way; with Reduce Motion it only cross-fades. Its own stack pushes the viewer from a result, so back returns to the
/// results with the query kept (E1). The root presents it as a clear full-screen cover without the cover's own slide.
struct SearchCover<Viewer: View>: View {
    let makeModel: () -> SearchModel
    let thumbnails: any ThumbnailProviding
    let viewer: (ScanID) -> Viewer
    /// Ends the cover once Search has gone; called without animation.
    let onClosed: () -> Void

    // B17: CaptureContainer's slide, "about 0.3 s, the standard iOS feel" (Task 20 Part C), and its Reduce Motion fade.
    // No motion tokens exist in design/tokens.json.
    private static var rise: Animation { .smooth(duration: 0.3) }
    private static var fade: Animation { .easeOut(duration: 0.2) }

    @Environment(\.reducesMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [ScanID] = []
    /// False before Search has risen and once its X is tapped.
    @State private var isShown = false
    /// True from the X until Search has gone; it closes once, by the animation's completion or, if backgrounding
    /// interrupted it, on becoming active again (as CaptureContainer's layer does).
    @State private var isLeaving = false

    var body: some View {
        NavigationStack(path: $path) {
            GridRoute(makeModel: makeModel) { model in
                SearchView(
                    model: model, thumbnails: thumbnails, onOpen: { path.append($0) }, onClose: leave)
            }
            .navigationDestination(for: ScanID.self) { viewer($0) }
        }
        // Opaque under every screen of the stack: the cover itself is clear so Home shows while Search fades.
        .background(Tokens.Color.bgGrouped)
        .opacity(isShown ? 1 : 0)
        .visualEffect { [rises = !isShown && !reduceMotion] content, proxy in
            // Down by its own bottom edge in the window: its top starts at least a screen height down.
            content.offset(y: rises ? proxy.frame(in: .global).maxY : 0)
        }
        .allowsHitTesting(isShown)
        .onAppear {
            withAnimation(reduceMotion ? Self.fade : Self.rise) { isShown = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isLeaving { finishLeaving() }
        }
    }

    private func leave() {
        guard !isLeaving else { return }
        isLeaving = true
        withAnimation(reduceMotion ? Self.fade : Self.rise) {
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
