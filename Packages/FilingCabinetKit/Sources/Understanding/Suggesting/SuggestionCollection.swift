import Core

/// A collection as the model sees it (M3). The model may only answer with one of the ids it is handed.
public struct SuggestionCollection: Sendable, Equatable {
    package let id: String
    package let name: String
    /// What belongs in it, in plain words.
    package let about: String

    package init(id: String, name: String, about: String) {
        self.id = id
        self.name = name
        self.about = about
    }

    /// The built-in collections in display order. The descriptions grow the requirements' cards (M3) into the kinds
    /// of document each holds, so the model can tell notes and wallet cards apart from documents (Task 4b).
    package static var builtIns: [Self] {
        BuiltInCollection.allCases.map(builtIn)
    }

    /// One built-in collection as the model sees it.
    package static func builtIn(_ collection: BuiltInCollection) -> Self {
        let (name, about) =
            switch collection {
            case .wallet:
                (
                    "Wallet",
                    "IDs and cards a person carries: driver's licenses, state and student IDs, passports, work "
                        + "and building badges, gym, club and library cards, insurance and vaccination cards, "
                        + "transit cards, business cards"
                )
            case .receipts:
                ("Receipts", "Receipts for anything bought or paid for: shops, restaurants, fuel, orders, services")
            case .notes:
                (
                    "Notes",
                    "Notes a person wrote, often by hand: class and lecture notes, meeting and call notes, "
                        + "lists, recipes"
                )
            case .documents:
                (
                    "Documents",
                    "Full pages to keep: forms, letters, bills, statements, contracts, records, anything else "
                        + "that isn't a card"
                )
            case .throwaways:
                (
                    "Throwaways",
                    "Short-lived scraps not needed after today: claim tags and stubs, used tickets, "
                        + "take-a-number slips"
                )
            }
        return Self(id: collection.rawValue, name: name, about: about)
    }
}
