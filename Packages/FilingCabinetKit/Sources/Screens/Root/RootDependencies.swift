import Core
import Library
import ScreenModels

/// Every model and provider the root navigation needs, built once by the app.
public struct RootDependencies {
    let home: HomeModel
    let flow: ScanFlowModel
    let makeGrid: (GridKind) -> CollectionGridModel
    let makeTrash: () -> TrashModel
    let makeViewer: (ScanID) -> ViewerModel
    let makeDetails: (ScanID) -> DetailsModel
    let thumbnails: any ThumbnailProviding
    let pages: any PageImageProviding
    let cameraMode: CameraMode
    /// `-ReduceMotion`: Reduce Motion's paths whatever the system setting, so UI tests can reach them.
    let forcesReduceMotion: Bool

    public init(
        home: HomeModel,
        flow: ScanFlowModel,
        makeGrid: @escaping (GridKind) -> CollectionGridModel,
        makeTrash: @escaping () -> TrashModel,
        makeViewer: @escaping (ScanID) -> ViewerModel,
        makeDetails: @escaping (ScanID) -> DetailsModel,
        thumbnails: any ThumbnailProviding,
        pages: any PageImageProviding,
        cameraMode: CameraMode,
        forcesReduceMotion: Bool
    ) {
        self.home = home
        self.flow = flow
        self.makeGrid = makeGrid
        self.makeTrash = makeTrash
        self.makeViewer = makeViewer
        self.makeDetails = makeDetails
        self.thumbnails = thumbnails
        self.pages = pages
        self.cameraMode = cameraMode
        self.forcesReduceMotion = forcesReduceMotion
    }
}
