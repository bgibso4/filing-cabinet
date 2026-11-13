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
    /// Trash's Restore, from a selection or one scan.
    case scansRestored(count: Int)
    /// Trash's Delete now, from a selection or one scan.
    case scansDeleted(count: Int)
    /// Trash's Empty Trash.
    case trashEmptied(count: Int)
    /// A cleanup pass (at launch or on return) deleted this many scans past their 30 days in Trash.
    case cleanupRan(deleted: Int)
    /// Settings › Collections › a collection's "Keep scans for".
    case lifespanChanged(collection: BuiltInCollection, lifespan: Lifespan)
    /// Favorite or Remove from Favorites, from the viewer, a selection or a tile's VoiceOver action (M19).
    case favoritesChanged(isFavorite: Bool, count: Int)
    /// Scans left the app: shared, saved to Photos or Files, or their text copied (M19).
    case scansExported(kind: ExportKind, count: Int)
    /// Search found this many scans for a word the person kept (M19). Never the word.
    case searchSaved(resultCount: Int)
    /// How the review's filing suggestion ended (M10). Never what it suggested.
    case suggestionOutcome(SuggestionOutcome)
    /// At save, after a suggestion arrived: whether the saved title and collection differ from the suggested ones (M10).
    case suggestionChanged(title: Bool, collection: Bool)
    /// The person opened a feedback email, from Settings or the failure screen (M14). Never what they write.
    case feedbackOpened(kind: FeedbackKind)
    /// The library couldn't open at launch or on Try again, so the failure screen shows (#40). Never the error.
    case libraryOpenFailed
    /// The first-launch welcome closed (M14): whether iOS lets the app post cleanup notes by then.
    case welcomeFinished(notifications: Bool)
    /// The app asked Apple for the rating prompt, which decides itself whether to show it.
    case ratingRequested

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
        case .scansRestored: "scansRestored"
        case .scansDeleted: "scansDeleted"
        case .trashEmptied: "trashEmptied"
        case .cleanupRan: "cleanupRan"
        case .lifespanChanged: "lifespanChanged"
        case .favoritesChanged: "favoritesChanged"
        case .scansExported: "scansExported"
        case .searchSaved: "searchSaved"
        case .suggestionOutcome: "suggestionOutcome"
        case .suggestionChanged: "suggestionChanged"
        case .feedbackOpened: "feedbackOpened"
        case .libraryOpenFailed: "libraryOpenFailed"
        case .welcomeFinished: "welcomeFinished"
        case .ratingRequested: "ratingRequested"
        }
    }

    public var payload: [AnalyticsKey: AnalyticsValue] {
        switch self {
        case .appOpened, .cameraDenied, .cameraFailed, .libraryOpenFailed, .ratingRequested: [:]
        case .scanStarted(let source): [.source: .token(.init(source))]
        case .scanCancelled(let stage): [.stage: .token(.init(stage))]
        case .scanSaved(let pageCount, let collection):
            [.pageCount: .int(pageCount), .collection: .token(.init(collection))]
        case .saveFailed(let reason): [.reason: .token(.init(reason))]
        case .textReadingFailed(let failedPages): [.failedPages: .int(failedPages)]
        case .scanEdited(let field): [.field: .token(.init(field))]
        case .scanMovedToTrash(let collection): [.collection: .token(.init(collection))]
        case .scansRestored(let count), .scansDeleted(let count), .trashEmptied(let count),
            .cleanupRan(let count):
            [.count: .int(count)]
        case .lifespanChanged(let collection, let lifespan):
            [.collection: .token(.init(collection)), .lifespan: .token(.init(lifespan))]
        case .favoritesChanged(let isFavorite, let count):
            [.isFavorite: .bool(isFavorite), .count: .token(.init(CountBucket(count)))]
        case .scansExported(let kind, let count):
            [.kind: .token(.init(kind)), .count: .token(.init(CountBucket(count)))]
        case .searchSaved(let resultCount): [.resultCount: .token(.init(CountBucket(resultCount)))]
        case .suggestionOutcome(let outcome): [.outcome: .token(.init(outcome))]
        case .suggestionChanged(let title, let collection):
            [.titleChanged: .bool(title), .collectionChanged: .bool(collection)]
        case .feedbackOpened(let kind): [.kind: .token(.init(kind))]
        case .welcomeFinished(let notifications): [.notifications: .bool(notifications)]
        }
    }
}
