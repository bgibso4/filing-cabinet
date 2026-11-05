import Core
import CoreGraphics
import Foundation
import Synchronization
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

@MainActor
private struct Harness {
    let analytics = RecordingAnalytics()
    let model: ScanFlowModel
    static let now = Date(timeIntervalSince1970: 1_791_806_400)
    static let clock = AppClock.fixed(now, calendar: Calendar(identifier: .gregorian))

    static func makeReview(_ input: ReviewInput) -> ReviewModel {
        ReviewModel(
            input: input,
            reader: ScanReader(reader: FakeTextReader([])),
            library: FakeLibrary(),
            clock: clock,
            analytics: RecordingAnalytics(),
            readingWaitLimit: .seconds(1)
        )
    }

    init(_ status: CameraAuthorization, grants: Bool = false) {
        model = ScanFlowModel(
            cameraAccess: FakeCameraAccess(status: status, grantsOnRequest: grants),
            clock: Self.clock,
            analytics: analytics,
            makeReview: Self.makeReview
        )
    }

    /// Scans from Home and finishes the first camera with `pages`.
    func reachReview(_ pages: [CGImage]) async {
        await model.scan(from: .home, preselected: nil)
        model.cameraFinished(pages)
    }
}

private let receipt = SyntheticPages.page(lines: [("ONE", 40)], size: CGSize(width: 60, height: 80))
private let other = SyntheticPages.page(lines: [("TWO", 40)], size: CGSize(width: 60, height: 80))

@Test func authorizedGoesStraightToCamera() async {
    let harness = Harness(.authorized)
    await harness.model.scan(from: .home, preselected: nil)
    #expect(harness.model.phase == .camera(isRescan: false))
}

@Test func notDeterminedAsksThenOpensCamera() async {
    let harness = Harness(.notDetermined, grants: true)
    await harness.model.scan(from: .home, preselected: nil)
    #expect(harness.model.phase == .camera(isRescan: false))
    #expect(harness.analytics.events == [.scanStarted(source: .home)])
}

@Test func deniedShowsCameraOffAndSendsCameraDenied() async {
    let harness = Harness(.denied)
    await harness.model.scan(from: .home, preselected: nil)
    #expect(harness.model.phase == .cameraOff)
    #expect(harness.analytics.events == [.scanStarted(source: .home), .cameraDenied])
    harness.model.dismissCameraOff()
    #expect(harness.model.phase == .idle)
}

@Test func refusedRequestShowsCameraOff() async {
    let harness = Harness(.notDetermined, grants: false)
    await harness.model.scan(from: .home, preselected: nil)
    #expect(harness.model.phase == .cameraOff)
    #expect(harness.analytics.events == [.scanStarted(source: .home), .cameraDenied])
}

@Test func cancellingTheFirstCameraSavesNothingAndSendsCancelled() async {
    let harness = Harness(.authorized)
    await harness.model.scan(from: .home, preselected: nil)
    harness.model.cameraCancelled()
    #expect(harness.model.phase == .idle)
    #expect(harness.model.reviewInput == nil)
    #expect(harness.analytics.events == [.scanStarted(source: .home), .scanCancelled(stage: .camera)])
}

@Test func cameraFailureSendsCameraFailedAndReturnsHome() async {
    let harness = Harness(.authorized)
    await harness.model.scan(from: .home, preselected: nil)
    harness.model.cameraFailed()
    #expect(harness.model.phase == .idle)
    #expect(harness.model.reviewInput == nil)
    // One event per failure (foundations §8): a failure is not also counted as a cancel.
    #expect(harness.analytics.events == [.scanStarted(source: .home), .cameraFailed])
}

@Test func finishingOpensReviewWithThePages() async {
    let harness = Harness(.authorized)
    await harness.model.scan(from: .grid, preselected: .receipts)
    harness.model.cameraFinished([receipt, other])
    #expect(harness.model.phase == .review)
    #expect(
        harness.model.reviewInput
            == ReviewInput(pages: [receipt, other], preselected: .receipts, scannedAt: Harness.now, source: .grid))
}

@Test func finishedRescanReplacesTheInput() async {
    let harness = Harness(.authorized)
    await harness.reachReview([receipt])
    harness.model.rescan()
    #expect(harness.model.phase == .camera(isRescan: true))
    harness.model.cameraFinished([other])
    #expect(harness.model.phase == .review)
    #expect(harness.model.reviewInput?.pages == [other])
}

@Test func cancelledRescanReturnsToReviewWithThePagesKept() async {
    let harness = Harness(.authorized)
    await harness.reachReview([receipt])
    harness.model.rescan()
    harness.model.cameraCancelled()
    #expect(harness.model.phase == .review)
    #expect(harness.model.reviewInput?.pages == [receipt])
    #expect(harness.analytics.events == [.scanStarted(source: .home)])
}

@Test func failedRescanReturnsToReview() async {
    let harness = Harness(.authorized)
    await harness.reachReview([receipt])
    harness.model.rescan()
    harness.model.cameraFailed()
    #expect(harness.model.phase == .review)
    #expect(harness.model.reviewInput?.pages == [receipt])
    #expect(harness.analytics.events == [.scanStarted(source: .home), .cameraFailed])
}

@Test func endingReviewReturnsHomeAndDropsTheInput() async {
    let harness = Harness(.authorized)
    await harness.reachReview([receipt])
    harness.model.reviewEnded()
    #expect(harness.model.phase == .idle)
    #expect(harness.model.reviewInput == nil)
}

@Test(arguments: [ScanSource.home, .grid])
func scanStartedCarriesItsSource(_ source: ScanSource) async {
    let harness = Harness(.authorized)
    await harness.model.scan(from: source, preselected: nil)
    #expect(harness.analytics.events == [.scanStarted(source: source)])
}

/// Camera access whose permission prompt stays up until the test answers it.
private final class PromptingCameraAccess: CameraAccess {
    private struct State {
        var requests = 0
        var prompt: CheckedContinuation<Bool, Never>?
    }

    private let state = Mutex(State())

    let status = CameraAuthorization.notDetermined

    var requests: Int { state.withLock { $0.requests } }

    func requestAccess() async -> Bool {
        await withCheckedContinuation { prompt in
            state.withLock { state in
                state.requests += 1
                state.prompt = prompt
            }
        }
    }

    func answer(_ granted: Bool) {
        state.withLock { $0.prompt.take() }?.resume(returning: granted)
    }
}

@Test(.timeLimit(.minutes(1)))
func scanningAgainWhileThePromptIsUpDoesNothing() async {
    let analytics = RecordingAnalytics()
    let access = PromptingCameraAccess()
    let model = ScanFlowModel(
        cameraAccess: access, clock: Harness.clock, analytics: analytics, makeReview: Harness.makeReview)
    let first = Task { await model.scan(from: .home, preselected: nil) }
    while access.requests == 0 { await Task.yield() }

    await model.scan(from: .home, preselected: nil)
    access.answer(true)
    await first.value

    #expect(access.requests == 1)
    #expect(analytics.events == [.scanStarted(source: .home)])
    #expect(model.phase == .camera(isRescan: false))
}
