import Testing

@testable import Understanding

private let builtIns = SuggestionCollection.builtIns

private func clean(title: String? = nil, collection: String? = nil, words: [String] = []) -> ScanSuggestion {
    SuggestionCleanup.clean(title: title, collectionID: collection, words: words, allowed: builtIns)
}

@Test func knownCollectionIsKept() {
    #expect(clean(collection: "receipts").collectionID == "receipts")
}

@Test func unknownCollectionIsDropped() {
    #expect(clean(collection: "taxes").collectionID == nil)
    #expect(clean(collection: nil).collectionID == nil)
}

@Test func titleIsTrimmedAndCollapsed() {
    #expect(clean(title: "  City   Pharmacy\n receipt ").title == "City Pharmacy receipt")
}

@Test func titleIsCutAtFortyOnAWord() {
    let title = clean(title: "Northwind Property Management lease renewal for unit 4B").title

    #expect(title == "Northwind Property Management lease")
    #expect((title?.count ?? 0) <= 40)
}

@Test func titleOfOneLongWordIsCutAtForty() {
    #expect(clean(title: String(repeating: "a", count: 60)).title == String(repeating: "a", count: 40))
}

@Test func titleOfExactlyFortyIsKept() {
    let forty = "Coat check ticket from the Grand Theatre"
    #expect(forty.count == 40)
    #expect(clean(title: forty).title == forty)
}

@Test func shortTitleIsDropped() {
    #expect(clean(title: "A1").title == nil)
    #expect(clean(title: "  ").title == nil)
    #expect(clean(title: nil).title == nil)
    #expect(clean(title: "W-2 2025").title == nil)  // one letter
    #expect(clean(title: "DMV").title == "DMV")
}

@Test func wordsAreDedupedAndCapped() {
    let words = (1...15).flatMap { ["word\($0)", "WORD\($0)x".lowercased()] }
    #expect(words.count == 30)

    let cleaned = clean(words: ["Receipt", "receipt", "RECEIPT"] + words).searchWords

    #expect(cleaned.count == 8)
    #expect(cleaned.first == "receipt")
    #expect(Set(cleaned.map { $0.lowercased() }).count == 8)
}

@Test func allCapsWordsKeepTheirCase() {
    #expect(
        clean(words: ["ID", "W-2", "Pharmacy", "DMV", "iPhone"]).searchWords == [
            "ID", "W-2", "pharmacy", "DMV", "iphone",
        ])
}

@Test func emptyWordsAreDropped() {
    #expect(clean(words: ["", "  ", "\n", "license"]).searchWords == ["license"])
}

@Test func overlongWordsAreDroppedAndSpacesCollapsed() {
    #expect(clean(words: [String(repeating: "x", count: 41), " parking   stub "]).searchWords == ["parking stub"])
}
