/// Whether the app may use the camera. `restricted` maps to `denied`: either way the user can't scan.
package enum CameraAuthorization: Sendable {
    case authorized
    case notDetermined
    case denied
}

/// The camera permission seam: the system's answer in the app, a scripted one in tests.
package protocol CameraAccess: Sendable {
    var status: CameraAuthorization { get }
    /// Asks the user (only when `notDetermined`); true when access is granted.
    func requestAccess() async -> Bool
}
