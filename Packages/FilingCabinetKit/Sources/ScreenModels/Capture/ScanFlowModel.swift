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

    /// The saved page on its way to its destination, after the capture layer has gone.
    package struct Flight: Equatable {
        package let saved: SavedScan
        package let from: CGRect
        package let destination: FlightDestination
        /// Page 1 alone: the other pages are released as review ends.
        package let page: CGImage
    }

    package private(set) var phase = Phase.idle
    package private(set) var reviewInput: ReviewInput?
    /// The review of `reviewInput`, made when the first camera finishes and kept through rescans.
    package private(set) var review: ReviewModel?
    package private(set) var flight: Flight?

    @ObservationIgnored private let cameraAccess: any CameraAccess
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let analytics: any Analytics
    @ObservationIgnored private let makeReview: (ReviewInput) -> ReviewModel
    /// Where the scan in progress started; set by `scan`, read when the first camera finishes.
    @ObservationIgnored private var source = ScanSource.home
    @ObservationIgnored private var preselected: BuiltInCollection?
    /// True while the system asks for camera access.
    @ObservationIgnored private var isAskingForCamera = false

    public init(
        cameraAccess: any CameraAccess,
        clock: AppClock,
        analytics: any Analytics,
        makeReview: @escaping (ReviewInput) -> ReviewModel
    ) {
        self.cameraAccess = cameraAccess
        self.clock = clock
        self.analytics = analytics
        self.makeReview = makeReview
    }

    /// Opens the camera, asking for access first if the user hasn't been asked; otherwise shows the camera-off sheet.
    /// Does nothing while a scan is under way, including while the permission prompt is up (`phase` is still idle
    /// then), so a second tap can't start a second scan.
    package func scan(from source: ScanSource, preselected: BuiltInCollection?) async {
        guard phase == .idle, !isAskingForCamera else { return }
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
            phase = .camera(isRescan: false)
        } else {
            analytics.send(.cameraDenied)
            phase = .cameraOff
        }
    }

    /// The first camera's pages start review; a rescan's replace the pages under review.
    package func cameraFinished(_ pages: [CGImage]) {
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

    package func rescan() {
        phase = .camera(isRescan: true)
    }

    package func dismissCameraOff() {
        phase = .idle
    }

    /// Review saved or discarded the scan. A saved scan's page 1 flies on from `rect`, its frame in review. The view
    /// ends the layer without animation for a save, since this module can't name SwiftUI's transactions.
    package func reviewEnded(saved: SavedScan?, from rect: CGRect?) {
        if let saved, let page = reviewInput?.pages.first {
            flight = Flight(
                saved: saved, from: rect ?? .zero, destination: Self.flightDestination(for: saved), page: page)
        }
        reviewInput = nil
        review = nil
        phase = .idle
    }

    /// Ends the flight; returns the announcement to post now that it has (M11).
    package func flightFinished() -> String? {
        defer { flight = nil }
        return flight?.saved.announcement
    }

    /// The scan's own tile when it started in a grid that shows the scan (Recent, All Scans or its collection);
    /// otherwise the collection's badge.
    package static func flightDestination(for saved: SavedScan) -> FlightDestination {
        let gridShowsIt = saved.source == .grid && (saved.preselected == nil || saved.preselected == saved.collection)
        return gridShowsIt ? .tile(saved.id) : .badge(saved.collection)
    }

    private func leaveCamera() {
        if reviewInput == nil {
            phase = .idle
        } else {
            phase = .review
        }
    }
}
