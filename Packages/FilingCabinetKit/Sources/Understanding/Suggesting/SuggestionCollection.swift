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

    /// The built-in collections in display order, with the requirements' wording.
    package static var builtIns: [Self] {
        BuiltInCollection.allCases.map { collection in
            let (name, about) =
                switch collection {
                case .wallet: ("Wallet", "IDs and cards: license, insurance, membership, business cards")
                case .receipts: ("Receipts", "Purchase receipts")
                case .notes: ("Notes", "Handwritten and class notes")
                case .documents: ("Documents", "Forms, letters, anything else")
                case .throwaways: ("Throwaways", "Short-lived scraps: coat-check tag, parking stub")
                }
            return Self(id: collection.rawValue, name: name, about: about)
        }
    }
}
