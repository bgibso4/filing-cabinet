import Core
import Library
import ScreenModels

/// Every model and provider the root navigation needs, built once by the app.
public struct RootDependencies {
    let home: HomeModel
    let flow: ScanFlowModel
    let makeGrid: (GridKind) -> CollectionGridModel
    let makeViewer: (ScanID) -> ViewerModel
    let thumbnails: any ThumbnailProviding
    let pages: any PageImageProviding
    let cameraMode: CameraMode

    public init(
        home: HomeModel,
        flow: ScanFlowModel,
        makeGrid: @escaping (GridKind) -> CollectionGridModel,
        makeViewer: @escaping (ScanID) -> ViewerModel,
        thumbnails: any ThumbnailProviding,
        pages: any PageImageProviding,
        cameraMode: CameraMode
    ) {
        self.home = home
        self.flow = flow
        self.makeGrid = makeGrid
        self.makeViewer = makeViewer
        self.thumbnails = thumbnails
        self.pages = pages
        self.cameraMode = cameraMode
    }
}
