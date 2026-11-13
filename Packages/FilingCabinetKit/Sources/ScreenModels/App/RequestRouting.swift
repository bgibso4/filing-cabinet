import Core

/// What the root is showing when a request from outside the app arrives.
package struct RootState {
    /// The welcome is completed and closed; until then every request waits (Plan 6 §4).
    package let welcomeFinished: Bool
    package let flowPhase: ScanFlowModel.Phase
    /// Search covers Home.
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

/// What the root does with a request.
package enum RootAction: Equatable {
    /// Leave it pending; the root asks again when what it shows changes.
    case wait
    /// Back to Home with nothing over it, then the camera, as Home's Scan.
    case startScan
    /// The review open under the request stays, and nothing else happens.
    case showReview
    /// Drop it.
    case ignore
    /// Open Search with the text; `closeOthers` first closes Search and every screen over Home.
    case search(String, closeOthers: Bool)
    /// Open the scan's viewer over Home; `closeOthers` first closes Search and every screen over Home.
    case open(ScanID, closeOthers: Bool)
}

/// What a request from outside the app does, given what is showing (M9): it waits for the welcome, closes Details,
/// Search and the viewer and then acts. An open review is brought back instead, and an open camera stays.
package enum RequestRouting {
    package static func action(for request: ExternalRequest, state: RootState) -> RootAction {
        guard state.welcomeFinished else { return .wait }
        switch state.flowPhase {
        case .review:
            return .showReview
        case .camera:
            return .ignore
        case .cameraOff:
            // Scan already asked for the camera; anything else opens once the sheet is closed, rather than racing it.
            return request == .scan ? .ignore : .wait
        case .idle:
            break
        }
        let closeOthers = state.isSearching || state.pathDepth > 0
        switch request {
        case .scan:
            return .startScan
        case .search(let text):
            return .search(text, closeOthers: closeOthers)
        case .open(let id):
            return state.isInLibrary(id) ? .open(id, closeOthers: closeOthers) : .ignore
        }
    }
}
