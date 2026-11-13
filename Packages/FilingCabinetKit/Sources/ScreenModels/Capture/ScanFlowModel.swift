import Core
import CoreGraphics
import Observation
import Understanding

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
    /// The review of `reviewInput`, made when the first camera finishes and kept through rescans.
    package private(set) var review: ReviewModel?
    /// The scan the last save made, for the haptic and the announcement; stays until the next save.
    package private(set) var lastSaved: SavedScan?

    @ObservationIgnored private let cameraAccess: any CameraAccess
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let analytics: any Analytics
    @ObservationIgnored private let makeReview: (ReviewInput) -> ReviewModel
    @ObservationIgnored private let suggester: any ScanSuggester
    /// Read as each camera opens, so the Settings switch takes effect on the next scan.
    @ObservationIgnored private let suggestionsOn: () -> Bool
    /// Where the scan in progress started; set by `scan`, read when the first camera finishes.
    @ObservationIgnored private var source = ScanSource.home
    @ObservationIgnored private var preselected: BuiltInCollection?
    /// True while the system asks for camera access.
    @ObservationIgnored private var isAskingForCamera = false
    /// Told when a scan starts (the Scan tap) and when it ends (saved, discarded, cancelled or the camera-off sheet
    /// dismissed), so the background words pass leaves the model to review meanwhile.
    @ObservationIgnored private let scanStarted: () -> Void
    @ObservationIgnored private let scanEnded: () -> Void

    public init(
        cameraAccess: any CameraAccess,
        clock: AppClock,
        analytics: any Analytics,
        suggester: any ScanSuggester,
        suggestionsOn: @escaping () -> Bool,
        makeReview: @escaping (ReviewInput) -> ReviewModel,
        scanStarted: @escaping () -> Void = {},
        scanEnded: @escaping () -> Void = {}
    ) {
        self.cameraAccess = cameraAccess
        self.clock = clock
        self.analytics = analytics
        self.suggester = suggester
        self.suggestionsOn = suggestionsOn
        self.makeReview = makeReview
        self.scanStarted = scanStarted
        self.scanEnded = scanEnded
    }

    /// Opens the camera, asking for access first if the user hasn't been asked; otherwise shows the camera-off sheet.
    /// Does nothing while a scan is under way, including while the permission prompt is up (`phase` is still idle
    /// then), so a second tap can't start a second scan.
    package func scan(from source: ScanSource, preselected: BuiltInCollection?) async {
        guard phase == .idle, !isAskingForCamera else { return }
        scanStarted()
        analytics.send(.scanStarted(source: source))
        self.source = source
        self.preselected = preselected
        let allowed: Bool
        switch cameraAccess.status {
        case .authorized:
            allowed = true
        case .notDetermined:
            isAskingForCamera = true
            allowed = await cameraAccess.requestAccess()
            isAskingForCamera = false
        case .denied:
            allowed = false
        }
        if allowed {
            openCamera(isRescan: false)
        } else {
            analytics.send(.cameraDenied)
            phase = .cameraOff
        }
    }

    /// The first camera's pages start review; a rescan's replace the pages under review.
    package func cameraFinished(_ pages: [CGImage]) {
        // Review needs a page to show. A camera that returns none (every page unreadable) has failed.
        guard !pages.isEmpty else { return cameraFailed() }
        if let reviewInput, let review {
            self.reviewInput = reviewInput.replacingPages(pages)
            review.replacePages(pages)
        } else {
            let input = ReviewInput(pages: pages, preselected: preselected, scannedAt: clock.now(), source: source)
            reviewInput = input
            review = makeReview(input)
        }
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

    /// True when closing the camera ends the scan (the first camera); a rescan's camera goes back to review.
    package var leavingCameraEndsTheScan: Bool { reviewInput == nil }

    package func rescan() {
        openCamera(isRescan: true)
    }

    package func dismissCameraOff() {
        endScan()
    }

    /// Review saved (`saved`) or discarded the scan. The view calls this once the layer has slid away, so the haptic
    /// and the announcement come after the slide.
    package func reviewEnded(saved: SavedScan?) {
        if let saved { lastSaved = saved }
        reviewInput = nil
        review = nil
        endScan()
    }

    /// Shows the camera, warming the model meanwhile so the review's suggestion comes sooner (E3).
    private func openCamera(isRescan: Bool) {
        if suggester.answers(whenOn: suggestionsOn()) {
            suggester.prewarm(collections: SuggestionCollection.builtIns)
        }
        phase = .camera(isRescan: isRescan)
    }

    private func endScan() {
        phase = .idle
        scanEnded()
    }

    private func leaveCamera() {
        if leavingCameraEndsTheScan {
            endScan()
        } else {
            phase = .review
        }
    }
}
