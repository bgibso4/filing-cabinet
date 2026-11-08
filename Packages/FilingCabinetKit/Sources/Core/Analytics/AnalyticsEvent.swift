/// Every event the app can report. Payload keys and values are typed, so an event cannot carry
/// free text.
public enum AnalyticsEvent: Sendable, Equatable {
    case appOpened
    case scanStarted(source: ScanSource)
    case cameraDenied
    /// VisionKit reported an error (one event per failure, foundations §8).
    case cameraFailed
    case scanCancelled(stage: CancelStage)
    case scanSaved(pageCount: Int, collection: BuiltInCollection)
    case saveFailed(reason: FailureReason)
    case textReadingFailed(failedPages: Int)
    case scanEdited(field: EditedField)
    /// The viewer's Trash button; a collection move into Trash reports `scanEdited` instead.
    case scanMovedToTrash(collection: BuiltInCollection)

    public var name: String {
        switch self {
        case .appOpened: "appOpened"
        case .scanStarted: "scanStarted"
        case .cameraDenied: "cameraDenied"
        case .cameraFailed: "cameraFailed"
        case .scanCancelled: "scanCancelled"
        case .scanSaved: "scanSaved"
        case .saveFailed: "saveFailed"
        case .textReadingFailed: "textReadingFailed"
        case .scanEdited: "scanEdited"
        case .scanMovedToTrash: "scanMovedToTrash"
        }
    }

    public var payload: [AnalyticsKey: AnalyticsValue] {
        switch self {
        case .appOpened, .cameraDenied, .cameraFailed: [:]
        case .scanStarted(let source): [.source: .token(.init(source))]
        case .scanCancelled(let stage): [.stage: .token(.init(stage))]
        case .scanSaved(let pageCount, let collection):
            [.pageCount: .int(pageCount), .collection: .token(.init(collection))]
        case .saveFailed(let reason): [.reason: .token(.init(reason))]
        case .textReadingFailed(let failedPages): [.failedPages: .int(failedPages)]
        case .scanEdited(let field): [.field: .token(.init(field))]
        case .scanMovedToTrash(let collection): [.collection: .token(.init(collection))]
        }
    }
}
