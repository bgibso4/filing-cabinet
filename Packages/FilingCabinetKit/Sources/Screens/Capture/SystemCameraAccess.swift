import AVFoundation
import Core

/// The system's camera permission.
public struct SystemCameraAccess: CameraAccess {
    public init() {}

    public var status: CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        // Restricted (parental controls, MDM) is as final as denied: the user can't scan either way.
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    public func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
