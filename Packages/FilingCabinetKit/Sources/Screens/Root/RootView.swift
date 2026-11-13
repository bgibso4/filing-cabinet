import Core
import ScreenModels
import StoreKit
import SwiftUI

/// The app's one navigation stack: Home at the root, collections, views and scans pushed on top. The capture layer
/// covers it while a scan is in the camera or in review; Search rises over Home (B17); the camera-off sheet slides
/// over it. On a first launch the welcome sheet covers Home until it is completed. Requests from outside the app (the
/// Scan control, Shortcuts, Siri, Spotlight) are acted on here once launch and the welcome have finished (M9).
public struct RootView: View {
    private let dependencies: RootDependencies
    private let canScan: Bool
    private let requests: ExternalRequests
    @State private var path: [AppRoute] = []
    /// True while Search covers Home.
    @State private var isSearching = false
    /// The text Search opens with: a request's, or empty from Home's field.
    @State private var searchQuery = ""
    /// Bumped when a request replaces an open Search's query, so Search is made again with it.
    @State private var searchRequests = 0
    /// Reduce Motion as Search went up: it fades rather than slides, in and out (B17).
    @State private var searchFades = false
    @Environment(\.accessibilityReduceMotion) private var systemReducesMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    /// Counts restores from the Trash viewer. Their success haptic plays here, because the viewer pops in the same
    /// update.
    @State private var restores = 0

    /// `canScan` is false until launch cleanup has finished, so a scan never races it, and no request is acted on
    /// before then.
    public init(dependencies: RootDependencies, canScan: Bool, requests: ExternalRequests) {
        self.dependencies = dependencies
        self.canScan = canScan
        self.requests = requests
    }

    public var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                model: dependencies.home,
                thumbnails: dependencies.thumbnails,
                canScan: canScan,
                onScan: { Task { await flow.scan(from: .home, preselected: nil) } },
                onSearch: { openSearch(query: "") },
                onOpen: { path.append($0) }
            )
            // Clear covers keep Home in the window under them; out of the accessibility tree meanwhile.
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
        // The layer has slid away (the flow ends the scan after it), so the prompt comes after the save, never during
        // the welcome, a review, the camera-off sheet or a confirmation (Plan 6 §4).
        .onChange(of: flow.phase) { _, phase in
            askForRatingIfDue(after: phase)
        }
        .fullScreenCover(isPresented: isCapturing) {
            CaptureContainer(flow: flow, cameraMode: dependencies.cameraMode)
                // Both of its screens are opaque. A clear presentation keeps the root in the window underneath, so Home
                // shows as the layer slides away; otherwise the screen is blank for two frames when the cover goes.
                .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $isSearching) {
            SearchCover(
                makeModel: { [searchQuery] in dependencies.makeSearch(searchQuery) },
                thumbnails: dependencies.thumbnails,
                viewer: { viewer($0, .library) },
                fades: searchFades,
                onClosed: { isSearching = false }
            )
            .id(searchRequests)
            // Fading, Search draws its own cross-fade over Home; sliding, the cover is opaque.
            .presentationBackground(searchFades ? AnyShapeStyle(.clear) : AnyShapeStyle(Tokens.Color.bgGrouped))
        }
        .sheet(isPresented: isCameraOff) {
            CameraOffSheet(onOpenSettings: flow.dismissCameraOff, onClose: flow.dismissCameraOff)
        }
        // Over Home, which can't scan or ask for anything while it is covered (Plan 6 §4).
        .sheet(isPresented: isWelcoming) {
            WelcomeSheet(model: dependencies.welcome)
        }
        .task { await dependencies.welcome.start() }
        // A request from outside the app, once nothing it must wait for is in the way.
        .onChange(of: requestMoment, initial: true) { actOnRequest() }
        // Back from iOS's notification ask: the welcome closes even if the answer never comes (M11).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { dependencies.welcome.becameActive() }
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

    private func askForRatingIfDue(after phase: ScanFlowModel.Phase) {
        guard phase == .idle, dependencies.rating.isDue, dependencies.welcome.isFinished, !isSearching,
            dependencies.welcome.step == nil
        else { return }
        requestReview()
        dependencies.rating.asked()
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

    /// The welcome can't be swiped away; the model decides when it closes.
    private var isWelcoming: Binding<Bool> {
        Binding(get: { dependencies.welcome.step != nil }, set: { _ in })
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

    /// Everything that decides what a pending request does; a change asks again.
    private var requestMoment: RequestMoment {
        RequestMoment(
            pending: requests.pending, canScan: canScan, welcomeFinished: welcomeFinished, flowPhase: flow.phase)
    }

    /// Completed, and its sheet gone. Before the welcome starts, `step` is nil but it isn't completed.
    private var welcomeFinished: Bool {
        dependencies.welcome.isFinished && dependencies.welcome.step == nil
    }

    /// Takes the pending request and acts on it (`RequestRouting`), unless it has to wait. Nothing is acted on before
    /// launch has finished.
    private func actOnRequest() {
        guard canScan, let request = requests.pending else { return }
        let state = RootState(
            welcomeFinished: welcomeFinished,
            flowPhase: flow.phase,
            isSearching: isSearching,
            pathDepth: path.count,
            isInLibrary: dependencies.home.isInLibrary)
        let action = RequestRouting.action(for: request, state: state)
        guard action != .wait else { return }
        _ = requests.take()
        switch action {
        case .wait, .ignore, .showReview:
            // A review already open is the capture layer, over everything: it is what shows.
            break
        case .startScan:
            // From Home, so saving or cancelling lands there.
            isSearching = false
            path = []
            Task { await flow.scan(from: .outside, preselected: nil) }
        case .search(let text, let closeOthers):
            if closeOthers { path = [] }
            if isSearching {
                // Made again with the new text; whatever was pushed on Search's own stack goes with it.
                searchQuery = text
                searchRequests += 1
            } else {
                openSearch(query: text)
            }
        case .open(let id, let closeOthers):
            if closeOthers { isSearching = false }
            path = [.scan(id)]
        }
    }

    /// Slides Search up with the cover's own slide; with Reduce Motion puts the cover up at once and lets Search fade in
    /// (SearchCover). `forcesReduceMotion` is read here because this view sets it for what is under it.
    private func openSearch(query: String) {
        searchQuery = query
        searchFades = systemReducesMotion || dependencies.forcesReduceMotion
        var transaction = Transaction()
        transaction.disablesAnimations = searchFades
        withTransaction(transaction) { isSearching = true }
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

/// What RootView's request handling depends on.
private struct RequestMoment: Equatable {
    // periphery:ignore - read only by the synthesized Equatable
    let pending: ExternalRequest?
    // periphery:ignore - read only by the synthesized Equatable
    let canScan: Bool
    // periphery:ignore - read only by the synthesized Equatable
    let welcomeFinished: Bool
    // periphery:ignore - read only by the synthesized Equatable
    let flowPhase: ScanFlowModel.Phase
}
