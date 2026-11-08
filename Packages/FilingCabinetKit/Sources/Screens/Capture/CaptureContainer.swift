import Core
import ScreenModels
import SwiftUI

/// The one full-screen capture layer (M20): the camera, then review, then any rescan swap inside it, so Home never
/// shows between them. Save, Discard and the first camera's Cancel slide the layer down like a closing sheet (a
/// cross-fade with Reduce Motion), then end it.
struct CaptureContainer: View {
    let flow: ScanFlowModel
    let cameraMode: CameraMode

    // Task 20 Part C (Ben): "about 0.3 s, the standard iOS feel". No motion tokens exist in design/tokens.json.
    private static let slide = Animation.smooth(duration: 0.3)
    // Task 20 Part C: "a quick cross-fade" under Reduce Motion. My call: 0.2 s.
    private static let fade = Animation.easeOut(duration: 0.2)

    @Environment(\.reducesMotion) private var reduceMotion
    /// True from the tap that ends the scan until the layer has slid away; the phase stays put meanwhile, so the
    /// cover keeps drawing this screen and Home stays out of the accessibility tree.
    @State private var isLeaving = false
    /// What ends the layer once the slide is over; taken by whichever comes first, the slide's completion or the app
    /// becoming active again (a slide interrupted by backgrounding may never complete), so the layer ends once.
    @State private var pendingEnd: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        screen
            .opacity(isLeaving && reduceMotion ? 0 : 1)
            .visualEffect { [slides = isLeaving && !reduceMotion] content, proxy in
                // Moving down by its own bottom edge in the window puts its top at least a screen height down.
                content.offset(y: slides ? proxy.frame(in: .global).maxY : 0)
            }
            .allowsHitTesting(!isLeaving)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { finishLeaving() }
            }
    }

    @ViewBuilder
    private var screen: some View {
        switch flow.phase {
        case .camera:
            camera
        case .review:
            if let review = flow.review {
                ReviewView(
                    model: review,
                    // ReviewView has already stopped reading (`discard()`); `reviewEnded` doesn't.
                    onClose: { leave { flow.reviewEnded(saved: nil) } },
                    onRescan: flow.rescan,
                    onSaved: { saved in leave { flow.reviewEnded(saved: saved) } }
                )
            }
        case .idle, .cameraOff:
            EmptyView()
        }
    }

    @ViewBuilder
    private var camera: some View {
        switch cameraMode {
        case .vision:
            DocumentCameraView(
                onFinish: flow.cameraFinished,
                onCancel: { leaveCamera(flow.cameraCancelled) },
                onFail: { leaveCamera(flow.cameraFailed) }
            )
            .ignoresSafeArea()
        case .fake(let pages):
            FakeCameraView(
                pages: pages, onFinish: flow.cameraFinished, onCancel: { leaveCamera(flow.cameraCancelled) })
        }
    }

    /// A rescan's camera goes straight back to review; the first camera's slides away first.
    private func leaveCamera(_ end: @escaping () -> Void) {
        if flow.leavingCameraEndsTheScan { leave(then: end) } else { end() }
    }

    /// Slides the layer away, then ends it. The cover then goes without its own animation: a clear cover's dismissal
    /// doesn't animate anyway (recorded, Task 20 Part C), and this screen is already off it.
    private func leave(then end: @escaping () -> Void) {
        guard !isLeaving else { return }
        pendingEnd = end
        withAnimation(reduceMotion ? Self.fade : Self.slide) {
            isLeaving = true
        } completion: {
            finishLeaving()
        }
    }

    /// Ends the layer if a slide is waiting to; does nothing otherwise, so a second caller can't end it twice.
    private func finishLeaving() {
        guard let end = pendingEnd else { return }
        pendingEnd = nil
        var cut = Transaction()
        cut.disablesAnimations = true
        withTransaction(cut, end)
    }
}
