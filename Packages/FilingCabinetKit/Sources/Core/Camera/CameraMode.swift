import CoreGraphics

/// Which camera the Scan button opens: VisionKit's document camera, or a fake that returns the pages the
/// app supplies (UI tests, M16). The closure keeps `Screens` free of `TestSupport` (M18).
public enum CameraMode: Sendable {
    case vision
    case fake(pages: @Sendable () -> [CGImage])
}
