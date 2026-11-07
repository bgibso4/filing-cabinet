import Core

/// One collection row on Home.
public struct HomeRow: Identifiable, Equatable, Sendable {
    /// What sits under or beside the name: the first-launch description, or the number of scans.
    public enum Detail: Equatable, Sendable {
        case subtitle(String)
        case count(Int)
    }

    public let collection: BuiltInCollection
    public let name: String
    public let detail: Detail

    public var id: BuiltInCollection { collection }

    /// The number to show, or nil for a subtitle. The saved page is still flying to `destination`, so this row's count
    /// doesn't include it yet, and ticks up as it lands.
    package func shownCount(during destination: FlightDestination?) -> Int? {
        guard case .count(let count) = detail else { return nil }
        return destination == .badge(collection) ? count - 1 : count
    }
}
