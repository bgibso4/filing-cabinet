import Core
import ScreenModels
import SwiftUI

/// The one full-screen capture layer (M20): the camera, then review, then any rescan swap inside it, so Home never
/// shows between them.
struct CaptureContainer: View {
    let flow: ScanFlowModel
    let cameraMode: CameraMode

    var body: some View {
        switch flow.phase {
        case .camera:
            camera
        case .review:
            if let review = flow.review {
                ReviewView(
                    model: review,
                    // ReviewView has already stopped reading (`discard()`); `reviewEnded` doesn't.
                    onClose: flow.reviewEnded,
                    onRescan: flow.rescan,
                    // Task 18 flies page 1 into its collection from here.
                    onSaved: { _, _ in flow.reviewEnded() }
                )
            }
        case .idle, .cameraOff:
            // Only seen while the layer is animating away.
            EmptyView()
        }
    }

    @ViewBuilder
    private var camera: some View {
        switch cameraMode {
        case .vision:
            DocumentCameraView(onFinish: flow.cameraFinished, onCancel: flow.cameraCancelled, onFail: flow.cameraFailed)
                .ignoresSafeArea()
        case .fake(let pages):
            FakeCameraView(pages: pages, onFinish: flow.cameraFinished, onCancel: flow.cameraCancelled)
        }
    }
}
