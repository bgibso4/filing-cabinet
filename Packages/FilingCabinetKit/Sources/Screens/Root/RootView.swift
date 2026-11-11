import Core
import ScreenModels
import SwiftUI

/// The app's one navigation stack: Home at the root, collections, views and scans pushed on top. The capture layer
/// covers it while a scan is in the camera or in review; Search rises over Home (B17); the camera-off sheet slides
/// over it.
public struct RootView: View {
    private let dependencies: RootDependencies
    private let canScan: Bool
    @State private var path: [AppRoute] = []
    /// True while Search covers Home.
    @State private var isSearching = false
    /// Counts restores from the Trash viewer. Their success haptic plays here, because the viewer pops in the same
    /// update.
    @State private var restores = 0

    /// `canScan` is false until launch cleanup has finished, so a scan never races it.
    public init(dependencies: RootDependencies, canScan: Bool) {
        self.dependencies = dependencies
        self.canScan = canScan
    }

    public var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                model: dependencies.home,
                thumbnails: dependencies.thumbnails,
                canScan: canScan,
                onScan: { Task { await flow.scan(from: .home, preselected: nil) } },
                onSearch: openSearch,
                onOpen: { path.append($0) }
            )
            // Both covers are clear, so Home stays in the window under them; out of the accessibility tree meanwhile.
            .accessibilityHidden(isCapturing.wrappedValue || isSearching)
            .background(BarHiddenFromAccessibility(isHidden: isCapturing.wrappedValue || isSearching))
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
        .sensoryFeedback(.success, trigger: restores)
        .onChange(of: flow.lastSaved) { _, saved in
            if let saved { AccessibilityNotification.Announcement(saved.announcement).post() }
        }
        .fullScreenCover(isPresented: isCapturing) {
            CaptureContainer(flow: flow, cameraMode: dependencies.cameraMode)
                // Both of its screens are opaque. A clear presentation keeps the root in the window underneath, so Home
                // shows as the layer slides away; otherwise the screen is blank for two frames when the cover goes.
                .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $isSearching) {
            SearchCover(
                makeModel: dependencies.makeSearch,
                thumbnails: dependencies.thumbnails,
                viewer: { viewer($0, .library) },
                onClosed: { isSearching = false }
            )
            // Search draws its own rise and fade over Home, which shows through as it does.
            .presentationBackground(.clear)
        }
        .sheet(isPresented: isCameraOff) {
            CameraOffSheet(onOpenSettings: flow.dismissCameraOff, onClose: flow.dismissCameraOff)
        }
        // Outermost, so the capture layer's cover gets it as well as Home.
        .environment(\.forcesReduceMotion, dependencies.forcesReduceMotion)
        // Settings › Appearance; nil follows the phone. Here so the cover and sheets, which present from this view,
        // and the system-drawn bar titles all follow it.
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch dependencies.preferences.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
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

    private func destination(_ route: AppRoute) -> some View {
        screen(route).accessibilityHidden(isCapturing.wrappedValue)
    }

    @ViewBuilder
    private func screen(_ route: AppRoute) -> some View {
        switch route {
        case .grid(let kind):
            grid(kind)
        case .trash:
            GridRoute(makeModel: dependencies.makeTrash) { model in
                TrashView(model: model, thumbnails: dependencies.thumbnails, onOpen: { path.append(.trashedScan($0)) })
            }
        case .scan(let id):
            viewer(id, .library)
        case .trashedScan(let id):
            viewer(id, .trash)
        case .settings:
            GridRoute(makeModel: dependencies.makeSettings) { model in
                SettingsView(model: model, onOpenCollections: { path.append(.collections) })
            }
        case .collections:
            GridRoute(makeModel: dependencies.makeCollections) { model in
                CollectionsView(model: model, onOpen: { path.append(.collectionSettings($0)) })
            }
        case .collectionSettings(let collection):
            GridRoute(
                makeModel: { dependencies.makeCollectionSettings(collection) }, content: CollectionSettingsView.init)
        }
    }

    /// Puts up the cover without its own slide: Search rises by itself (SearchCover).
    private func openSearch() {
        var cut = Transaction()
        cut.disablesAnimations = true
        withTransaction(cut) { isSearching = true }
    }

    /// The mode decides the viewer's controls: opened from Trash, ViewerView shows nothing that opens Details.
    private func viewer(_ id: ScanID, _ mode: ViewerModel.Mode) -> some View {
        ViewerRoute(
            makeModel: { dependencies.makeViewer(id, mode) },
            makeDetails: { dependencies.makeDetails(id) },
            pages: dependencies.pages,
            thumbnails: dependencies.thumbnails,
            onRestored: { restores += 1 }
        )
    }

    private func grid(_ kind: GridKind) -> some View {
        GridRoute(
            makeModel: { dependencies.makeGrid(kind) },
            content: { model in
                CollectionGridView(
                    model: model,
                    thumbnails: dependencies.thumbnails,
                    canScan: canScan,
                    onOpen: { path.append(.scan($0)) },
                    onScan: { Task { await flow.scan(from: .grid, preselected: kind.preselection) } }
                )
            })
    }
}
