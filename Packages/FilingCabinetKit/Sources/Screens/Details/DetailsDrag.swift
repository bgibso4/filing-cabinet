import CoreGraphics

/// A vertical drag that moves Details, in points down the screen as UIKit reports them. The viewer follows the finger
/// from where Details was when the drag began, and lets the spring settle it on release.
public enum DetailsDrag: Equatable, Sendable {
    case began
    case changed(translation: CGFloat)
    /// The release, at this speed in points per second.
    case ended(velocity: CGFloat)
}
