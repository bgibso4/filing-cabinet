import Core

/// What the root is showing when a request from outside the app arrives.
package struct RootState {
    /// The welcome is completed and closed; until then every request waits (Plan 6 §4).
    package let welcomeFinished: Bool
    package let flowPhase: ScanFlowModel.Phase
    /// Search's cover is up, or still leaving.
    package let isSearching: Bool
    /// How many screens are pushed over Home; the viewer (and Details, a panel in it) is one of them.
    package let pathDepth: Int
    /// Whether a scan is in the library now, not in Trash, expired or deleted.
    package let isInLibrary: (ScanID) -> Bool

    package init(
        welcomeFinished: Bool,
        flowPhase: ScanFlowModel.Phase,
        isSearching: Bool,
        pathDepth: Int,
        isInLibrary: @escaping (ScanID) -> Bool
    ) {
        self.welcomeFinished = welcomeFinished
        self.flowPhase = flowPhase
        self.isSearching = isSearching
        self.pathDepth = pathDepth
        self.isInLibrary = isInLibrary
    }
}

/// What the root does with a request. The close steps leave it pending: once the screen has gone, it is routed again.
package enum RootAction: Equatable {
    /// Leave it pending; the root asks again when what it shows changes.
    case wait
    /// Close Search through its own close (its slide or, with Reduce Motion, its fade), then ask again once its cover
    /// has gone, so nothing presents while it is still leaving.
    case closeSearch
    /// Pop every screen over Home (the viewer takes Details with it), then ask again.
    case popToHome
    /// The camera, from Home, as Home's Scan.
    case startScan
    /// The review open under the request stays, and nothing else happens.
    case showReview
    /// Drop it.
    case ignore
    /// Open Search with the text, over Home.
    case search(String)
    /// Open the scan's viewer, over Home.
    case open(ScanID)
}

/// What a request from outside the app does, given what is showing (M9): it waits for the welcome, closes Search and
/// then Details and the viewer, one step at a time, and then acts. An open review is brought back instead, and an open
/// camera stays.
package enum RequestRouting {
    package static func action(for request: ExternalRequest, state: RootState) -> RootAction {
        guard state.welcomeFinished else { return .wait }
        if let capturing = action(for: request, during: state.flowPhase) { return capturing }
        // Checked before closing anything, so a scan that has gone closes nothing.
        if case .open(let id) = request, !state.isInLibrary(id) { return .ignore }
        if state.isSearching { return .closeSearch }
        // Even the same scan's viewer is popped, so it opens again without Details.
        if state.pathDepth > 0 { return .popToHome }
        switch request {
        case .scan: return .startScan
        case .search(let text): return .search(text)
        case .open(let id): return .open(id)
        }
    }

    /// What a scan under way does to the request; nil when no scan is.
    private static func action(for request: ExternalRequest, during phase: ScanFlowModel.Phase) -> RootAction? {
        switch phase {
        case .review: .showReview
        case .camera: .ignore
        // Scan already asked for the camera; anything else opens once the sheet is closed, rather than racing it.
        case .cameraOff: request == .scan ? .ignore : .wait
        case .idle: nil
        }
    }
}
