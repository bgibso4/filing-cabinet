import Testing

@testable import Understanding

private func input(_ pages: [String], collections: [SuggestionCollection] = SuggestionCollection.builtIns)
    -> SuggestionInput
{
    SuggestionInput(pageTexts: pages, firstPage: nil, collections: collections)
}

@Test func promptListsEveryCollectionIdNameAndAbout() {
    let prompt = SuggestionPrompt.prompt(for: input(["CITY PHARMACY"]), budget: 6_000)

    for collection in SuggestionCollection.builtIns {
        #expect(prompt.contains("- \(collection.id): \(collection.name) · \(collection.about)"))
    }
    #expect(prompt.contains("CITY PHARMACY"))
}

@Test func customCollectionsAppear() {
    let taxes = SuggestionCollection(id: "taxes", name: "Taxes", about: "Tax forms and records")

    let prompt = SuggestionPrompt.prompt(
        for: input(["W-2"], collections: SuggestionCollection.builtIns + [taxes]), budget: 6_000)

    #expect(prompt.contains("- taxes: Taxes · Tax forms and records"))
}

@Test func longTextIsTrimmedPageOneFirst() {
    let pages = (0..<20).map { String(repeating: Character(UnicodeScalar(UInt8(65 + $0))), count: 2_000) }

    let trimmed = SuggestionPrompt.trimmed(pages, budget: 6_000)

    #expect(trimmed.count == 20)
    #expect(trimmed.first == pages.first)
    #expect(trimmed.dropFirst().allSatisfy { !$0.isEmpty && $0.count < 2_000 })
    #expect(trimmed.reduce(0) { $0 + $1.count } <= 6_000)
    // The prompt carries page 1 whole, and every page in order.
    let prompt = SuggestionPrompt.prompt(for: input(pages), budget: 6_000)
    #expect(prompt.contains(pages[0]))
    #expect(prompt.contains("Page 20:"))
}

@Test func shortPagesLeaveTheirShareToLaterPages() {
    let trimmed = SuggestionPrompt.trimmed(["one", "two", String(repeating: "x", count: 100)], budget: 50)

    #expect(trimmed == ["one", "two", String(repeating: "x", count: 44)])
}

@Test func pageOneLongerThanTheBudgetIsCut() {
    let trimmed = SuggestionPrompt.trimmed([String(repeating: "a", count: 100), "b"], budget: 10)

    #expect(trimmed == [String(repeating: "a", count: 10), ""])
}

@Test func blankPagesAreLeftOutOfThePrompt() {
    let prompt = SuggestionPrompt.prompt(for: input(["front", "  \n", "back"]), budget: 6_000)

    #expect(prompt.contains("Page 1:\nfront"))
    #expect(prompt.contains("Page 3:\nback"))
    #expect(!prompt.contains("Page 2:"))
}

@Test func collectionIDsAreUniqueInOrder() {
    let taxes = SuggestionCollection(id: "taxes", name: "Taxes", about: "Tax forms")
    let again = SuggestionCollection(id: "taxes", name: "Taxes 2", about: "More tax forms")

    #expect(
        SuggestionPrompt.collectionIDs(in: [taxes] + SuggestionCollection.builtIns + [again]) == ["taxes"]
            + SuggestionCollection.builtIns.map(\.id))
}

@Test func wordsPromptHasTheTitleTheCollectionNameAndTheStartOfTheText() {
    let pages = [String(repeating: "a", count: 500), "", String(repeating: "b", count: 500)]

    let prompt = SuggestionPrompt.wordsPrompt(
        for: input(pages), title: "City Pharmacy Receipt", collectionName: "Receipts")

    #expect(prompt.contains("Title: City Pharmacy Receipt"))
    #expect(prompt.contains("Collection: Receipts"))
    // 600 characters of text, across pages; blank pages are skipped.
    #expect(prompt.contains(String(repeating: "a", count: 500) + "\n" + String(repeating: "b", count: 99)))
    #expect(!prompt.contains(String(repeating: "b", count: 100)))
}

@Test func instructionsHaveNoPlaceholdersAndNameNoCollection() {
    let instructions = SuggestionPrompt.instructions

    #expect(!instructions.contains("<") && !instructions.contains(">"))
    for collection in SuggestionCollection.builtIns {
        #expect(!instructions.contains(collection.name), "names \(collection.name)")
    }
    #expect(!instructions.lowercased().contains("wallet"))
    #expect(!instructions.lowercased().contains("throwaway"))
}

@Test func promptStartsWithTheCollectionsPrefix() {
    let collections = SuggestionCollection.builtIns

    let prefix = SuggestionPrompt.prefix(for: collections)

    #expect(SuggestionPrompt.prompt(for: input(["CITY PHARMACY"]), budget: 6_000).hasPrefix(prefix))
    #expect(prefix.hasSuffix("Text read from the scan:\n"))
}

@Test func inputFromSearchTextSplitsItsPages() {
    let input = SuggestionInput(
        searchText: "CITY PHARMACY\nTOTAL 12.40\n\nCORNER MARKET", firstPage: nil, collections: [])

    #expect(input.pageTexts == ["CITY PHARMACY\nTOTAL 12.40", "CORNER MARKET"])
}
