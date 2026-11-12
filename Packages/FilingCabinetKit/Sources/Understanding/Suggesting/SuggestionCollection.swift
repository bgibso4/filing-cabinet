import Core

/// A collection as the model sees it (M3). The model may only answer with one of the ids it is handed.
package struct SuggestionCollection: Sendable, Equatable {
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
        BuiltInCollection.allCases.map { collection in
            let (name, about) =
                switch collection {
                case .wallet:
                    (
                        "Wallet",
                        "IDs and cards a person carries: license, passport, ID badges, insurance and health cards, "
                            + "membership, transit and business cards"
                    )
                case .receipts:
                    ("Receipts", "Receipts for anything bought or paid for: shops, restaurants, fuel, orders, services")
                case .notes:
                    (
                        "Notes",
                        "Notes a person wrote, often by hand: class and lecture notes, meeting and call notes, "
                            + "lists, recipes"
                    )
                case .documents: ("Documents", "Forms, letters, bills, statements, contracts, anything else to keep")
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
}
