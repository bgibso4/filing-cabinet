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
            .accessibilityHidden(isCapturing.wrappedValue)
            // Home draws its own large title (Home.dc.html); pushed screens bring their own headers.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .environment(\.captureLayerIsUp, isCapturing.wrappedValue)
        // Home holds still under the layer and catches up once it has slid away, so the count ticks and pops in view.
        // `hold()` runs just after the render in which the layer appears; that is fine, because nothing can be saved
        // until the camera has finished.
        .onChange(of: isCapturing.wrappedValue) { _, isUp in
            if isUp {
                dependencies.home.hold()
            } else {
                withAnimation { dependencies.home.release() }
            }
        }
        .sensoryFeedback(.success, trigger: flow.lastSaved) { _, new in new != nil }
        .onChange(of: flow.lastSaved) { _, saved in
            if let saved { AccessibilityNotification.Announcement(saved.announcement).post() }
        }
        .fullScreenCover(isPresented: isCapturing) {
            CaptureContainer(flow: flow, cameraMode: dependencies.cameraMode)
                // Both of its screens are opaque. A clear presentation keeps the root in the window underneath, so Home
                // shows as the layer slides away; otherwise the screen is blank for two frames when the cover goes.
                .presentationBackground(.clear)
        }
        .sheet(isPresented: isCameraOff) {
            CameraOffSheet(onOpenSettings: flow.dismissCameraOff, onClose: flow.dismissCameraOff)
        }
        // Outermost, so the capture layer's cover gets it as well as Home.
        .environment(\.forcesReduceMotion, dependencies.forcesReduceMotion)
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

    private func destination(_ route: AppRoute) -> some View {
        screen(route).accessibilityHidden(isCapturing.wrappedValue)
    }

    @ViewBuilder
    private func screen(_ route: AppRoute) -> some View {
        switch route {
        case .collection(let collection):
            grid(.collection(collection))
        case .recent:
            grid(.recent)
        case .all:
            grid(.all)
        case .scan(let id):
            ViewerRoute(
                makeModel: { dependencies.makeViewer(id) },
                pages: dependencies.pages,
                thumbnails: dependencies.thumbnails
            )
        }
    }

    private func grid(_ kind: GridKind) -> some View {
        CollectionGridView(
            model: dependencies.makeGrid(kind),
            thumbnails: dependencies.thumbnails,
            canScan: canScan,
            onOpen: { path.append(.scan($0)) },
            onScan: { Task { await flow.scan(from: .grid, preselected: kind.preselection) } }
        )
    }
}
