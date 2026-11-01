/// A payload value. The rule: no free text, ever. Text enters a payload only as a case of one of
/// our own enums conforming to `AnalyticsToken`; new payload values are added the same way.
public enum AnalyticsValue: Sendable, Equatable {
    case int(Int)
    case bool(Bool)
    case token(AnalyticsTokenValue)
}

/// An enum whose raw values are fixed, app-defined strings.
public protocol AnalyticsToken: RawRepresentable, Sendable where RawValue == String {}

/// The erased form of a token. It has no string initializer, so arbitrary text cannot get in.
public struct AnalyticsTokenValue: Sendable, Equatable {
    private let raw: String

    public init(_ token: some AnalyticsToken) {
        raw = token.rawValue
    }
}
