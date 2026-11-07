import CoreGraphics
import Foundation

/// How the saved page reaches its destination: flying there, or fading where it is (M13, Reduce Motion).
package enum FlightStyle: Equatable {
    case fly
    case fade

    // My call, all four: Review.dc.html has no timing beyond what the plan sets (0.45 s spring, 0.2 s cross-fade).
    /// How long the page holds still before its destination is read. The screen under the capture layer only lays
    /// out the new scan once the layer has gone, so a frame read any earlier is stale or missing. Long enough for that
    /// layout pass, short enough not to read as a pause. A destination with no frame by then fades in place.
    package static let destinationWait: TimeInterval = 0.1
    package static let flyDuration: TimeInterval = 0.45
    /// The page's last moment on the destination, after it has shrunk there.
    package static let landingFadeDuration: TimeInterval = 0.15
    package static let fadeDuration: TimeInterval = 0.2

    package static func choose(reduceMotion: Bool, hasDestination: Bool) -> Self {
        !reduceMotion && hasDestination ? .fly : .fade
    }

    /// `frame`, if it can be seen in `region`: the middle of it is inside. A frame scrolled away, or never measured,
    /// is no destination.
    package static func landingFrame(_ frame: CGRect?, visibleIn region: CGRect) -> CGRect? {
        guard let frame, !frame.isEmpty, region.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return nil }
        return frame
    }
}
