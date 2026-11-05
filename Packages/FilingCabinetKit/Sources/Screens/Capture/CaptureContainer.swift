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
            // Task 15 puts the review screen here.
            Tokens.Color.bgGrouped.ignoresSafeArea()
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
