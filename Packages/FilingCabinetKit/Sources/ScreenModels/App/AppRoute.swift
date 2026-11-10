import Core

/// Where the root navigation stack can go from Home.
public enum AppRoute: Hashable {
    case collection(BuiltInCollection)
    case recent
    case all
    case favorites
    case trash
    case scan(ScanID)
    /// A scan opened from Trash, with Restore and Delete now.
    case trashedScan(ScanID)
    case settings
    case collections
    case collectionSettings(BuiltInCollection)
    /// Search, from Home's field (M14, E1).
    case search
}

extension AppRoute {
    /// The grid a route shows, or nil for a screen that isn't a grid (Trash has its own).
    package var gridKind: GridKind? {
        switch self {
        case .collection(let collection): .collection(collection)
        case .recent: .recent
        case .all: .all
        case .favorites: .favorites
        case .trash, .scan, .trashedScan, .settings, .collections, .collectionSettings, .search: nil
        }
    }
}
