import Core

/// Where the root navigation stack can go from Home.
public enum AppRoute: Hashable {
    /// A collection, Recent, All Scans or Favorites: `GridKind` is the one list of grids.
    case grid(GridKind)
    case trash
    case scan(ScanID)
    /// A scan opened from Trash, with Restore and Delete now.
    case trashedScan(ScanID)
    case settings
    case collections
    case collectionSettings(BuiltInCollection)
}
