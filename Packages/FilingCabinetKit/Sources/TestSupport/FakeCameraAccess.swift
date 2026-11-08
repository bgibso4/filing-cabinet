import Core

/// Camera access with a scripted status and a scripted answer to the permission prompt.
public struct FakeCameraAccess: CameraAccess {
    public let status: CameraAuthorization
    private let grantsOnRequest: Bool

    public init(status: CameraAuthorization, grantsOnRequest: Bool) {
        self.status = status
        self.grantsOnRequest = grantsOnRequest
    }

    public func requestAccess() async -> Bool {
        grantsOnRequest
    }
}
