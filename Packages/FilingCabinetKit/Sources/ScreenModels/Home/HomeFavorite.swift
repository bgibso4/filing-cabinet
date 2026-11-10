import Core

/// One card in Home's Favorites row (02-01): it opens the scan.
package struct HomeFavorite: Identifiable, Equatable {
    package let id: ScanID
    package let title: String
}
