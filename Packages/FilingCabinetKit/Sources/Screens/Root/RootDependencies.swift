import Core
import Library
import ScreenModels

/// Every model and provider the root navigation needs, built once by the app. Later tasks add the scan flow,
/// the grid and the viewer.
public struct RootDependencies {
    let home: HomeModel
    // periphery:ignore - read by the collection grid (Task 16); the app builds it now.
    let thumbnails: any ThumbnailProviding
    // periphery:ignore - read by the viewer (Task 17); the app builds it now.
    let pages: any PageImageProviding
    // periphery:ignore - read by the capture layer (Task 13); the app builds it now.
    let cameraMode: CameraMode

    public init(
        home: HomeModel,
        thumbnails: any ThumbnailProviding,
        pages: any PageImageProviding,
        cameraMode: CameraMode
    ) {
        self.home = home
        self.thumbnails = thumbnails
        self.pages = pages
        self.cameraMode = cameraMode
    }
}
