import Core

/// Where the root navigation stack can go from Home.
public enum AppRoute: Hashable {
    case collection(BuiltInCollection)
    case recent
    case all
    case trash
    case scan(ScanID)
    /// A scan opened from Trash, with Restore and Delete now.
    case trashedScan(ScanID)
}
