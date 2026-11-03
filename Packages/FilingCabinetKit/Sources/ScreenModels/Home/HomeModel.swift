import Core
import Foundation
import Observation

/// What Home shows on first launch: the five built-in collections with their lifespans.
@Observable
public final class HomeModel {
    public let rows: [HomeRow]

    public init() {
        rows = BuiltInCollection.allCases.map { collection in
            HomeRow(
                collection: collection,
                name: Self.name(of: collection),
                subtitle: Self.description(of: collection) + " · " + Self.text(for: collection.lifespan)
            )
        }
    }

    private static func name(of collection: BuiltInCollection) -> String {
        switch collection {
        case .wallet: String(localized: "Wallet", bundle: #bundle)
        case .receipts: String(localized: "Receipts", bundle: #bundle)
        case .notes: String(localized: "Notes", bundle: #bundle)
        case .documents: String(localized: "Documents", bundle: #bundle)
        case .throwaways: String(localized: "Throwaways", bundle: #bundle)
        }
    }

    private static func description(of collection: BuiltInCollection) -> String {
        switch collection {
        case .wallet: String(localized: "IDs and cards", bundle: #bundle)
        case .receipts: String(localized: "Purchase receipts", bundle: #bundle)
        case .notes: String(localized: "Handwritten notes", bundle: #bundle)
        case .documents: String(localized: "Forms and letters", bundle: #bundle)
        case .throwaways: String(localized: "Short-lived scraps", bundle: #bundle)
        }
    }

    private static func text(for lifespan: Lifespan) -> String {
        switch lifespan {
        case .forever: String(localized: "Kept forever", bundle: #bundle)
        case .week: String(localized: "\(1) weeks", bundle: #bundle)
        case .month: String(localized: "\(1) months", bundle: #bundle)
        case .threeMonths: String(localized: "\(3) months", bundle: #bundle)
        case .year: String(localized: "\(1) years", bundle: #bundle)
        }
    }
}
