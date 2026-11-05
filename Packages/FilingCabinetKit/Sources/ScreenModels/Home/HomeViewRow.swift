/// One row of Home's views card: Recent or All Scans.
public struct HomeViewRow: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case recent
        case all
    }

    public let kind: Kind
    public let name: String
    /// Nil for Recent, which shows no number (Home.dc.html lists only All Scans with a count).
    public let count: Int?

    public var id: Kind { kind }
}
