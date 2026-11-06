import Core
import Library
import ScreenModels

/// Every model and provider the root navigation needs, built once by the app. A later task adds the viewer.
public struct RootDependencies {
    let home: HomeModel
    let flow: ScanFlowModel
    let makeGrid: (GridKind) -> CollectionGridModel
    let thumbnails: any ThumbnailProviding
    // periphery:ignore - read by the viewer (Task 17); the app builds it now.
    let pages: any PageImageProviding
    let cameraMode: CameraMode

    public init(
        home: HomeModel,
        flow: ScanFlowModel,
        makeGrid: @escaping (GridKind) -> CollectionGridModel,
        thumbnails: any ThumbnailProviding,
        pages: any PageImageProviding,
        cameraMode: CameraMode
    ) {
        self.home = home
        self.flow = flow
        self.makeGrid = makeGrid
        self.thumbnails = thumbnails
        self.pages = pages
        self.cameraMode = cameraMode
    }
}
