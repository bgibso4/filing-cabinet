import ScreenModels
import SwiftUI

/// The app's one navigation stack: Home at the root, collections, views and scans pushed on top. The capture layer
/// covers it while a scan is in the camera or in review; the camera-off sheet slides over it. A saved page flies over
/// everything once the capture layer has gone.
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
        .environment(\.flightDestination, visibleFlightDestination)
        .overlayPreferenceValue(FlightTargetFrameKey.self) { frame in
            FlightOverlay(flow: flow, targetFrame: frame, forcesReduceMotion: dependencies.forcesReduceMotion)
        }
        .sensoryFeedback(.success, trigger: flow.flight) { _, new in new != nil }
        .fullScreenCover(isPresented: isCapturing) {
            CaptureContainer(flow: flow, cameraMode: dependencies.cameraMode)
                // Both of its screens are opaque. A clear presentation keeps the root in the window underneath, so it
                // is already drawn the moment the layer goes; otherwise the screen is blank for two frames.
                .presentationBackground(.clear)
                // That also leaves the root reachable: keep VoiceOver in the layer.
                .accessibilityAddTraits(.isModal)
        }
        .sheet(isPresented: isCameraOff) {
            CameraOffSheet(onOpenSettings: flow.dismissCameraOff, onClose: flow.dismissCameraOff)
        }
    }

    private var flow: ScanFlowModel { dependencies.flow }

    /// The current flight's destination if it is on the top screen. Home's rows stay laid out under a pushed grid, so
    /// scanning in Receipts and saving to Wallet has nowhere to land (M13).
    private var visibleFlightDestination: FlightDestination? {
        guard let destination = flow.flight?.destination else { return nil }
        if case .badge = destination, !path.isEmpty { return nil }
        return destination
    }

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

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
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
