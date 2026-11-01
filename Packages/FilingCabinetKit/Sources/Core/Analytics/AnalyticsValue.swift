/// A payload value. The rule: no free text, ever. Text enters a payload only as a case of one of
/// our own enums conforming to `AnalyticsToken`; new payload values are added the same way.
public enum AnalyticsValue: Sendable, Equatable {
    // periphery:ignore - analytics payload vocabulary; first used by the first token-carrying event
    case int(Int)
    // periphery:ignore - analytics payload vocabulary; first used by the first token-carrying event
    case bool(Bool)
    // periphery:ignore - analytics payload vocabulary; first used by the first token-carrying event
    case token(AnalyticsTokenValue)
}

// periphery:ignore - analytics payload vocabulary; first used by the first token-carrying event
/// An enum whose raw values are fixed, app-defined strings.
///
/// Only the package can mint tokens: the protocol and `AnalyticsTokenValue.init(_:)` are
/// `package`, so the app target cannot create one. Inside the package, the SwiftLint rule
/// `analytics_token_enum_only` requires the conformance on the enum's own declaration: a
/// struct, class, actor or extension conformance is rejected (a type with a stored string
/// could otherwise smuggle free text in).
package protocol AnalyticsToken: RawRepresentable, Sendable where RawValue == String {}

// periphery:ignore - analytics payload vocabulary; first used by the first token-carrying event
/// The erased form of a token. It has no string initializer, so arbitrary text cannot get in.
public struct AnalyticsTokenValue: Sendable, Equatable {
    private let raw: String

    package init(_ token: some AnalyticsToken) {
        raw = token.rawValue
    }
}
