/// A payload value. The rule: no free text, ever. Text enters a payload only as a case of one of
/// our own enums conforming to `AnalyticsToken`; new payload values are added the same way.
public enum AnalyticsValue: Sendable, Equatable {
    case int(Int)
    // periphery:ignore - analytics payload vocabulary; no event carries a flag yet
    case bool(Bool)
    case token(AnalyticsTokenValue)
}

/// An enum whose raw values are fixed, app-defined strings.
///
/// Only the package can mint tokens: the protocol and `AnalyticsTokenValue.init(_:)` are
/// `package`, so the app target cannot create one. Inside the package, the SwiftLint rule
/// `analytics_token_enum_only` requires the conformance on the enum's own declaration: a
/// struct, class, actor or extension conformance is rejected (a type with a stored string
/// could otherwise smuggle free text in).
package protocol AnalyticsToken: RawRepresentable, Sendable where RawValue == String {}

/// The erased form of a token. It has no string initializer, so arbitrary text cannot get in.
public struct AnalyticsTokenValue: Sendable, Equatable {
    // periphery:ignore - read by the synthesized Equatable and by LogAnalytics' description of the payload
    private let raw: String

    package init(_ token: some AnalyticsToken) {
        raw = token.rawValue
    }
}
