/// One row of Home's views card: Recent, Favorites, All Scans or Trash.
public struct HomeViewRow: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case favorites
        case recent
        case all
        case trash
    }

    public let kind: Kind
    public let name: String
    /// Nil for Recent, which shows no number (Home.dc.html lists only All Scans and Trash with a count), and for no
    /// favourites or an empty Trash.
    public let count: Int?

    public var id: Kind { kind }
}
