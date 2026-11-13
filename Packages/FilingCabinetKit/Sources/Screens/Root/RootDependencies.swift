import Core
import Library
import ScreenModels

/// Every model and provider the root navigation needs, built once by the app.
public struct RootDependencies {
    let home: HomeModel
    let flow: ScanFlowModel
    let makeGrid: (GridKind) -> CollectionGridModel
    let makeTrash: () -> TrashModel
    let makeViewer: (ScanID, ViewerModel.Mode) -> ViewerModel
    let makeDetails: (ScanID) -> DetailsModel
    let makeSettings: () -> SettingsModel
    let makeCollections: () -> CollectionsModel
    let makeCollectionSettings: (BuiltInCollection) -> CollectionSettingsModel
    let makeSearch: () -> SearchModel
    let thumbnails: any ThumbnailProviding
    let pages: any PageImageProviding
    let cameraMode: CameraMode
    /// `-ReduceMotion`: Reduce Motion's paths whatever the system setting, so UI tests can reach them.
    let forcesReduceMotion: Bool
    /// Read at the root for Settings › Appearance.
    let preferences: AppPreferences
    /// The first-launch welcome, a sheet over Home until it is completed.
    let welcome: WelcomeModel

    public init(
        home: HomeModel,
        flow: ScanFlowModel,
        makeGrid: @escaping (GridKind) -> CollectionGridModel,
        makeTrash: @escaping () -> TrashModel,
        makeViewer: @escaping (ScanID, ViewerModel.Mode) -> ViewerModel,
        makeDetails: @escaping (ScanID) -> DetailsModel,
        makeSettings: @escaping () -> SettingsModel,
        makeCollections: @escaping () -> CollectionsModel,
        makeCollectionSettings: @escaping (BuiltInCollection) -> CollectionSettingsModel,
        makeSearch: @escaping () -> SearchModel,
        thumbnails: any ThumbnailProviding,
        pages: any PageImageProviding,
        cameraMode: CameraMode,
        forcesReduceMotion: Bool,
        preferences: AppPreferences,
        welcome: WelcomeModel
    ) {
        self.home = home
        self.flow = flow
        self.makeGrid = makeGrid
        self.makeTrash = makeTrash
        self.makeViewer = makeViewer
        self.makeDetails = makeDetails
        self.makeSettings = makeSettings
        self.makeCollections = makeCollections
        self.makeCollectionSettings = makeCollectionSettings
        self.makeSearch = makeSearch
        self.thumbnails = thumbnails
        self.pages = pages
        self.cameraMode = cameraMode
        self.forcesReduceMotion = forcesReduceMotion
        self.preferences = preferences
        self.welcome = welcome
    }
}
