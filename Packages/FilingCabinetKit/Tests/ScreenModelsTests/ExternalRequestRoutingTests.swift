import Core
import Testing

@testable import ScreenModels

/// Home at rest, the welcome finished, unless a test says otherwise; `missing` is not in the library.
private func state(
    welcomeFinished: Bool = true,
    phase: ScanFlowModel.Phase = .idle,
    isSearching: Bool = false,
    pathDepth: Int = 0,
    missing: ScanID? = nil
) -> RootState {
    RootState(
        welcomeFinished: welcomeFinished,
        flowPhase: phase,
        isSearching: isSearching,
        pathDepth: pathDepth,
        isInLibrary: { $0 != missing })
}

nonisolated private let scan = ScanID()

@Test(arguments: [ExternalRequest.scan, .search("lease"), .open(scan)])
func waitsForTheWelcome(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(welcomeFinished: false)) == .wait)
}

@Test func scanFromHomeStartsTheCamera() {
    #expect(RequestRouting.action(for: .scan, state: state()) == .startScan)
    #expect(RequestRouting.action(for: .scan, state: state(isSearching: true, pathDepth: 2)) == .startScan)
}

@Test(arguments: [ExternalRequest.scan, .search("lease"), .open(scan)])
func reviewOpenBringsItBack(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(phase: .review)) == .showReview)
}

@Test(arguments: [ExternalRequest.scan, .search("lease"), .open(scan)])
func cameraOpenIgnoresScan(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(phase: .camera(isRescan: false))) == .ignore)
    #expect(RequestRouting.action(for: request, state: state(phase: .camera(isRescan: true))) == .ignore)
}

@Test func cameraOffSheetIgnoresScan() {
    #expect(RequestRouting.action(for: .scan, state: state(phase: .cameraOff)) == .ignore)
}

@Test(arguments: [ExternalRequest.search("lease"), .open(scan)])
func cameraOffSheetHoldsSearchAndOpenUntilItCloses(_ request: ExternalRequest) {
    #expect(RequestRouting.action(for: request, state: state(phase: .cameraOff)) == .wait)
}

@Test func searchOpensSearch() {
    #expect(RequestRouting.action(for: .search("lease"), state: state()) == .search("lease", closeOthers: false))
}

@Test func searchReplacesTheQuery() {
    #expect(
        RequestRouting.action(for: .search("lease"), state: state(isSearching: true))
            == .search("lease", closeOthers: true))
    #expect(
        RequestRouting.action(for: .search("lease"), state: state(pathDepth: 1))
            == .search("lease", closeOthers: true))
}

@Test func openFromHomePushesTheViewer() {
    #expect(RequestRouting.action(for: .open(scan), state: state()) == .open(scan, closeOthers: false))
}

@Test func openClosesDetailsAndSearch() {
    // Details is a panel in the viewer, so a pushed viewer (with or without it) is a path deeper than Home.
    #expect(RequestRouting.action(for: .open(scan), state: state(pathDepth: 1)) == .open(scan, closeOthers: true))
    #expect(RequestRouting.action(for: .open(scan), state: state(isSearching: true)) == .open(scan, closeOthers: true))
}

@Test func openIgnoresAScanNoLongerInTheLibrary() {
    #expect(RequestRouting.action(for: .open(scan), state: state(isSearching: true, missing: scan)) == .ignore)
}
