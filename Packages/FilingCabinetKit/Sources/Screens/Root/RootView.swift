import Core
import ScreenModels
import SwiftUI

/// The app's one navigation stack: Home at the root, collections, views and scans pushed on top. The capture layer
/// covers it while a scan is in the camera or in review; the camera-off sheet slides over it.
public struct RootView: View {
    private let dependencies: RootDependencies
    private let canScan: Bool
    @State private var path: [AppRoute] = []

    /// `canScan` is false until launch cleanup has finished, so a scan never races it.
    public init(dependencies: RootDependencies, canScan: Bool) {
        self.dependencies = dependencies
        self.canScan = canScan
    }

    public var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                model: dependencies.home,
                canScan: canScan,
                onScan: { Task { await flow.scan(from: .home, preselected: nil) } },
                onOpen: { path.append($0) }
            )
            // Home draws its own large title (Home.dc.html); pushed screens bring their own headers.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .fullScreenCover(isPresented: isCapturing) {
            CaptureContainer(flow: flow, cameraMode: dependencies.cameraMode)
        }
        .sheet(isPresented: isCameraOff) {
            CameraOffSheet(onOpenSettings: flow.dismissCameraOff, onClose: flow.dismissCameraOff)
        }
    }

    private var flow: ScanFlowModel { dependencies.flow }

    /// The capture layer can't be swiped away; the flow decides when it ends.
    private var isCapturing: Binding<Bool> {
        Binding(
            get: {
                switch flow.phase {
                case .camera, .review: true
                case .idle, .cameraOff: false
                }
            },
            set: { _ in }
        )
    }

    /// Swiping the sheet down closes it like the close button.
    private var isCameraOff: Binding<Bool> {
        Binding(
            get: { flow.phase == .cameraOff },
            set: { isPresented in
                if !isPresented { flow.dismissCameraOff() }
            }
        )
    }

    /// Placeholders until the grid (Task 16) and the viewer (Task 17) fill these in.
    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .collection(let collection):
            placeholder(CollectionText.name(collection))
        case .recent:
            placeholder(CollectionText.recent)
        case .all:
            placeholder(CollectionText.allScans)
        case .scan:
            Tokens.Color.bgGrouped.ignoresSafeArea()
        }
    }

    private func placeholder(_ name: String) -> some View {
        Text(name)
            .accessibilityIdentifier(AccessibilityID.Grid.header)
    }
}
