import Core
import Foundation

/// Every collection string: names, descriptions, lifespans and empty states.
package enum CollectionText {
    /// The names of Home's two views.
    package static var recent: String { String(localized: "Recent", bundle: #bundle) }
    package static var allScans: String { String(localized: "All Scans", bundle: #bundle) }

    /// Recent's subtitle.
    static var lastThirtyDays: String { String(localized: "Last 30 days", bundle: #bundle) }

    /// "91 scans", "1 scan", "No scans" (M15).
    static func scanCount(_ count: Int) -> String {
        count == 0
            ? String(localized: "No scans", bundle: #bundle) : String(localized: "\(count) scans", bundle: #bundle)
    }

    package static func name(_ collection: BuiltInCollection) -> String {
        switch collection {
        case .wallet: String(localized: "Wallet", bundle: #bundle)
        case .receipts: String(localized: "Receipts", bundle: #bundle)
        case .notes: String(localized: "Notes", bundle: #bundle)
        case .documents: String(localized: "Documents", bundle: #bundle)
        case .throwaways: String(localized: "Throwaways", bundle: #bundle)
        }
    }

    /// What the collection's scans are called in copy (M5): "receipt" for one, "receipts" for any other count.
    static func noun(_ collection: BuiltInCollection, count: Int) -> String {
        switch (collection, count == 1) {
        case (.wallet, true): String(localized: "card", bundle: #bundle)
        case (.wallet, false): String(localized: "cards", bundle: #bundle)
        case (.receipts, true): String(localized: "receipt", bundle: #bundle)
        case (.receipts, false): String(localized: "receipts", bundle: #bundle)
        case (.notes, true): String(localized: "note", bundle: #bundle)
        case (.notes, false): String(localized: "notes", bundle: #bundle)
        case (.documents, true): String(localized: "document", bundle: #bundle)
        case (.documents, false): String(localized: "documents", bundle: #bundle)
        case (.throwaways, true): String(localized: "throwaway", bundle: #bundle)
        case (.throwaways, false): String(localized: "throwaways", bundle: #bundle)
        }
    }

    /// What scans from mixed or unknown collections are called (M5).
    static func scansNoun(count: Int) -> String {
        count == 1 ? String(localized: "scan", bundle: #bundle) : String(localized: "scans", bundle: #bundle)
    }

    static func description(_ collection: BuiltInCollection) -> String {
        switch collection {
        case .wallet: String(localized: "IDs and cards", bundle: #bundle)
        case .receipts: String(localized: "Purchase receipts", bundle: #bundle)
        case .notes: String(localized: "Handwritten notes", bundle: #bundle)
        case .documents: String(localized: "Forms and letters", bundle: #bundle)
        case .throwaways: String(localized: "Short-lived scraps", bundle: #bundle)
        }
    }

    /// "Kept forever", "1 week", "1 month", "3 months", "1 year".
    static func lifespanShort(_ lifespan: Lifespan) -> String {
        switch lifespan {
        case .forever: String(localized: "Kept forever", bundle: #bundle)
        case .week: String(localized: "\(1) weeks", bundle: #bundle)
        case .month: String(localized: "\(1) months", bundle: #bundle)
        case .threeMonths: String(localized: "\(3) months", bundle: #bundle)
        case .year: String(localized: "\(1) years", bundle: #bundle)
        }
    }

    /// "Kept 1 week", "Kept forever".
    static func kept(_ lifespan: Lifespan) -> String {
        switch lifespan {
        case .forever: String(localized: "Kept forever", bundle: #bundle)
        default: String(localized: "Kept \(lifespanShort(lifespan))", bundle: #bundle)
        }
    }

    /// "3 scans · Kept 3 months".
    static func scanCountAndKept(_ count: Int, _ lifespan: Lifespan) -> String {
        String(localized: "\(scanCount(count)) · \(kept(lifespan))", bundle: #bundle)
    }

    static func emptyTitle(_ grid: GridKind) -> String {
        switch grid {
        case .collection(.wallet): String(localized: "No cards yet", bundle: #bundle)
        case .collection(.receipts): String(localized: "No receipts yet", bundle: #bundle)
        case .collection(.notes): String(localized: "No notes yet", bundle: #bundle)
        case .collection(.documents): String(localized: "No documents yet", bundle: #bundle)
        case .collection(.throwaways): String(localized: "No throwaways", bundle: #bundle)
        case .recent: String(localized: "Nothing recent", bundle: #bundle)
        case .all: String(localized: "No scans yet", bundle: #bundle)
        }
    }

    static func emptyBody(_ grid: GridKind) -> String {
        switch grid {
        case .collection(.wallet):
            String(
                localized: "IDs and cards go here, like your license and insurance card. They’re kept forever.",
                bundle: #bundle)
        case .collection(.receipts):
            String(
                localized: "Purchase receipts go here. Each one is kept 3 months, then moves to Trash.",
                bundle: #bundle)
        case .collection(.notes):
            String(localized: "Handwritten and class notes go here. They’re kept forever.", bundle: #bundle)
        case .collection(.documents):
            String(localized: "Forms, letters and anything else go here. They’re kept forever.", bundle: #bundle)
        case .collection(.throwaways):
            String(
                localized: "Short-lived scraps go here, like a coat-check tag. Each one is kept a week.",
                bundle: #bundle)
        case .recent: String(localized: "Scans from the last 30 days show up here.", bundle: #bundle)
        case .all: String(localized: "Every scan shows up here, newest first.", bundle: #bundle)
        }
    }
}
