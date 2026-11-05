import Core
import CoreGraphics
import Observation

/// One scan from the Scan button to the end of review: camera permission, the camera, rescans and review.
/// The root presents the capture layer while `phase` is `.camera` or `.review`, and the camera-off sheet for
/// `.cameraOff`.
@MainActor
@Observable
public final class ScanFlowModel {
    package enum Phase: Equatable {
        case idle
        case camera(isRescan: Bool)
        case cameraOff
        case review
    }

    package private(set) var phase = Phase.idle
    package private(set) var reviewInput: ReviewInput?

    @ObservationIgnored private let cameraAccess: any CameraAccess
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let analytics: any Analytics
    /// Where the scan in progress started; set by `scan`, read when the first camera finishes.
    @ObservationIgnored private var source = ScanSource.home
    @ObservationIgnored private var preselected: BuiltInCollection?

    public init(cameraAccess: any CameraAccess, clock: AppClock, analytics: any Analytics) {
        self.cameraAccess = cameraAccess
        self.clock = clock
        self.analytics = analytics
    }

    /// Opens the camera, asking for access first if the user hasn't been asked; otherwise shows the camera-off sheet.
    package func scan(from source: ScanSource, preselected: BuiltInCollection?) async {
        analytics.send(.scanStarted(source: source))
        self.source = source
        self.preselected = preselected
        let allowed =
            switch cameraAccess.status {
            case .authorized: true
            case .notDetermined: await cameraAccess.requestAccess()
            case .denied: false
            }
        if allowed {
            phase = .camera(isRescan: false)
        } else {
            analytics.send(.cameraDenied)
            phase = .cameraOff
        }
    }

    /// The first camera's pages start review; a rescan's replace the pages under review.
    package func cameraFinished(_ pages: [CGImage]) {
        reviewInput =
            reviewInput?.replacingPages(pages)
            ?? ReviewInput(pages: pages, preselected: preselected, scannedAt: clock.now(), source: source)
        phase = .review
    }

    /// The first camera cancelled ends the scan with nothing saved; a cancelled rescan goes back to review.
    package func cameraCancelled() {
        if phase == .camera(isRescan: false) { analytics.send(.scanCancelled(stage: .camera)) }
        leaveCamera()
    }

    /// Where a cancel goes, but counted as a failure rather than also as a cancel (one event per failure).
    package func cameraFailed() {
        analytics.send(.cameraFailed)
        leaveCamera()
    }

    package func rescan() {
        phase = .camera(isRescan: true)
    }

    package func dismissCameraOff() {
        phase = .idle
    }

    /// Review saved or discarded the scan.
    package func reviewEnded() {
        reviewInput = nil
        phase = .idle
    }

    private func leaveCamera() {
        if reviewInput == nil {
            phase = .idle
        } else {
            phase = .review
        }
    }
}
