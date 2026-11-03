import Core

/// Where the root navigation stack can go from Home.
package enum AppRoute: Hashable {
    case collection(BuiltInCollection)
    case recent
    case all
    case scan(ScanID)
}
