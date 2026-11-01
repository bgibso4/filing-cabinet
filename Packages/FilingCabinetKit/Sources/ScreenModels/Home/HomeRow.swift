import Core

/// One collection row on Home.
public struct HomeRow: Identifiable, Equatable, Sendable {
    public let collection: BuiltInCollection
    public let name: String
    public let subtitle: String

    public var id: BuiltInCollection { collection }
}
