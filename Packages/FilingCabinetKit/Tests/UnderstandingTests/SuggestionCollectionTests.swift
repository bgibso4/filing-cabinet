import Core
import Testing

@testable import Understanding

@Test func builtInsMatchBuiltInCollection() {
    #expect(SuggestionCollection.builtIns.map(\.id) == BuiltInCollection.allCases.map(\.rawValue))
}

@Test func builtInsUseTheRequirementsWording() {
    let wallet = SuggestionCollection.builtIns.first
    #expect(wallet?.name == "Wallet")
    #expect(wallet?.about == "IDs and cards: license, insurance, membership, business cards")
    #expect(SuggestionCollection.builtIns.allSatisfy { !$0.name.isEmpty && !$0.about.isEmpty })
}
