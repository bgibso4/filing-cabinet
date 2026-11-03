import Core

/// Camera access with a scripted status and a scripted answer to the permission prompt.
package struct FakeCameraAccess: CameraAccess {
    package let status: CameraAuthorization
    private let grantsOnRequest: Bool

    package init(status: CameraAuthorization, grantsOnRequest: Bool) {
        self.status = status
        self.grantsOnRequest = grantsOnRequest
    }

    package func requestAccess() async -> Bool {
        grantsOnRequest
    }
}
