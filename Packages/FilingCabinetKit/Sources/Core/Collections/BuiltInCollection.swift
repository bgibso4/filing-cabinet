/// The five collections every library starts with. `allCases` is display order.
public enum BuiltInCollection: String, Sendable, CaseIterable, AnalyticsToken {
    case wallet
    case receipts
    case notes
    case documents
    case throwaways

    /// Read only by `CollectionLifespans`.
    package var defaultLifespan: Lifespan {
        switch self {
        case .wallet, .notes, .documents: .forever
        case .receipts: .threeMonths
        case .throwaways: .week
        }
    }
}
