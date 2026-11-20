import Core
import Testing

@testable import ScreenModels

/// Home at rest, the welcome finished, unless a test says otherwise; `missing` is not in the library.
private func state(
    welcomeFinished: Bool = true,
    isLocked: Bool = false,
    phase: ScanFlowModel.Phase = .idle,
    isSearching: Bool = false,
    pathDepth: Int = 0,
    missing: ScanID? = nil
) -> RootState {
    RootState(
        welcomeFinished: welcomeFinished,
        isLocked: isLocked,
        flowPhase: phase,
        isSearching: isSearching,
        pathDepth: pathDepth,
        isInLibrary: { $0 != missing })
}

nonisolated private let scan = ScanID()

@Test(arguments: [ExternalRequest.scan, .search("lease"), .open(scan), .trash])
func waitsForTheWelcome(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(welcomeFinished: false)) == .wait)
}

@Test func scanFromHomeStartsTheCamera() {
    #expect(RequestRouting.action(for: .scan, state: state()) == .startScan)
}

@Test func scanWhileSearchingClosesSearchFirst() {
    #expect(RequestRouting.action(for: .scan, state: state(isSearching: true)) == .closeSearch)
    // Once Search's cover has gone, the same request is routed again.
    #expect(RequestRouting.action(for: .scan, state: state()) == .startScan)
}

@Test(arguments: [ExternalRequest.scan, .search("lease"), .open(scan), .trash])
func searchClosesBeforeTheScreensUnderIt(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(isSearching: true, pathDepth: 2)) == .closeSearch)
    #expect(RequestRouting.action(for: request, state: state(pathDepth: 2)) == .popToHome)
}

@Test(arguments: [ExternalRequest.scan, .search("lease"), .open(scan), .trash])
func reviewOpenBringsItBack(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(phase: .review)) == .showReview)
}

@Test(arguments: [ExternalRequest.scan, .search("lease"), .open(scan), .trash])
func cameraOpenIgnoresScan(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(phase: .camera(isRescan: false))) == .ignore)
    #expect(RequestRouting.action(for: request, state: state(phase: .camera(isRescan: true))) == .ignore)
}

@Test func cameraOffSheetIgnoresScan() {
    #expect(RequestRouting.action(for: .scan, state: state(phase: .cameraOff)) == .ignore)
}

@Test(arguments: [ExternalRequest.search("lease"), .open(scan), .trash])
func cameraOffSheetHoldsSearchAndOpenUntilItCloses(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(phase: .cameraOff)) == .wait)
}

@Test func searchOpensSearch() {
    #expect(RequestRouting.action(for: .search("lease"), state: state()) == .search("lease"))
}

@Test func searchReplacesTheQuery() {
    // Search already open: it closes, then opens again with the new text.
    #expect(RequestRouting.action(for: .search("lease"), state: state(isSearching: true)) == .closeSearch)
    #expect(RequestRouting.action(for: .search("lease"), state: state()) == .search("lease"))
}

@Test func openFromHomePushesTheViewer() {
    #expect(RequestRouting.action(for: .open(scan), state: state()) == .show(.scan(scan)))
}

@Test func openClosesDetailsAndSearch() {
    #expect(RequestRouting.action(for: .open(scan), state: state(isSearching: true)) == .closeSearch)
    // Details is a panel in the viewer: popping the viewer closes it, even when it is this scan's viewer.
    #expect(RequestRouting.action(for: .open(scan), state: state(pathDepth: 1)) == .popToHome)
    #expect(RequestRouting.action(for: .open(scan), state: state()) == .show(.scan(scan)))
}

@Test func openIgnoresAScanNoLongerInTheLibrary() {
    // Nothing is closed for it.
    #expect(RequestRouting.action(for: .open(scan), state: state(isSearching: true, missing: scan)) == .ignore)
}

@Test func searchWaitsWhileLocked() {
    #expect(RequestRouting.action(for: .search("x"), state: state(isLocked: true)) == .wait)
}

@Test func openWaitsWhileLockedEvenForAScanThatHasGone() {
    #expect(RequestRouting.action(for: .open(scan), state: state(isLocked: true)) == .wait)
    #expect(RequestRouting.action(for: .open(scan), state: state(isLocked: true, missing: scan)) == .wait)
}

@Test func scanFromHomeStartsTheCameraWhileLocked() {
    #expect(RequestRouting.action(for: .scan, state: state(isLocked: true)) == .startScan)
}

@Test func scanWhileLockedPopsAPushedScreen() {
    #expect(RequestRouting.action(for: .scan, state: state(isLocked: true, pathDepth: 1)) == .popToHome)
}

@Test func scanWhileLockedBringsTheReviewBack() {
    #expect(RequestRouting.action(for: .scan, state: state(isLocked: true, phase: .review)) == .showReview)
}

@Test func trashFromHomeOpensTrash() {
    #expect(RequestRouting.action(for: .trash, state: state()) == .show(.trash))
}

@Test func trashPopsWhatIsPushedFirst() {
    // Trash itself too: it opens again from Home, at its top.
    #expect(RequestRouting.action(for: .trash, state: state(pathDepth: 1)) == .popToHome)
}

@Test func trashWaitsWhileLocked() {
    #expect(RequestRouting.action(for: .trash, state: state(isLocked: true)) == .wait)
}
