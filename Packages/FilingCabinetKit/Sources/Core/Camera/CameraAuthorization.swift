/// Whether the app may use the camera. `restricted` maps to `denied`: either way the user can't scan.
public enum CameraAuthorization: Sendable {
    case authorized
    case notDetermined
    case denied
}
