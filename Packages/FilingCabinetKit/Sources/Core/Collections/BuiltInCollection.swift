/// The five collections every library starts with. `allCases` is display order.
public enum BuiltInCollection: String, Sendable, CaseIterable {
    case wallet
    case receipts
    case notes
    case documents
    case throwaways

    public var lifespan: Lifespan {
        switch self {
        case .wallet, .notes, .documents: .forever
        case .receipts: .threeMonths
        case .throwaways: .week
        }
    }
}
