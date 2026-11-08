/// How long a scan stays in a collection before cleanup considers it. `allCases` is the order of the
/// "Keep scans for" choices: shortest first, Forever last.
public enum Lifespan: String, Sendable, CaseIterable, AnalyticsToken {
    case week
    case month
    case threeMonths
    case year
    case forever

    /// Fixed days, not calendar months: 7, 30, 90 or 365. Nil means forever.
    public var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .year: 365
        case .forever: nil
        }
    }
}
