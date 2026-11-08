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
    /// Goes up each time Home catches up after a scan and this row's count went up; the count pops on each change.
    package let pulse: Int

    public var id: BuiltInCollection { collection }
}
