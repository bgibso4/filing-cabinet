/// The camera permission seam: the system's answer in the app, a scripted one in tests.
public protocol CameraAccess: Sendable {
    var status: CameraAuthorization { get }
    /// Asks the user (only when `notDetermined`); true when access is granted.
    func requestAccess() async -> Bool
}
