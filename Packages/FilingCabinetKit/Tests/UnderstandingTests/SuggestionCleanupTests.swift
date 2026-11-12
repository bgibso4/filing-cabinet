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
    #expect(clean(title: "  City   Pharmacy\n Receipt ").title == "City Pharmacy Receipt")
}

@Test func titleIsCutAtFortyOnAWord() {
    let title = clean(title: "Northwind Property Management lease renewal for unit 4B").title

    #expect(title == "Northwind Property Management Lease")
    #expect((title?.count ?? 0) <= 40)
}

@Test func titleOfOneLongWordIsCutAtForty() {
    #expect(clean(title: String(repeating: "Ab", count: 30)).title == String(repeating: "Ab", count: 20))
}

@Test func titleOfExactlyFortyIsKept() {
    let forty = "Coat Check Ticket from the Grand Theatre"
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

@Test func titleLosesLeadingAndTrailingSeparators() {
    #expect(clean(title: "W-2 Wage and Tax Statement 2026 · ").title == "W-2 Wage and Tax Statement 2026")
    #expect(clean(title: " - Coat Check Ticket:").title == "Coat Check Ticket")
    #expect(clean(title: "· , City Pharmacy Receipt ,").title == "City Pharmacy Receipt")
}

@Test func titleCollapsesEmptySeparators() {
    #expect(clean(title: "2025 W-2 ·  · Northwind").title == "2025 W-2 · Northwind")
}

@Test func titleCutNeverEndsOnASeparator() {
    #expect(
        clean(title: "Certificate of Vehicle Registration · Northwind").title == "Certificate of Vehicle Registration")
}

@Test func titleOfOnlySeparatorsIsDropped() {
    #expect(clean(title: " · - : ").title == nil)
}

@Test func mergedWordsPreferTheFocusedCallsWords() {
    let focused = ["pharmacy", "drugstore", "medicine", "health", "Medical"]
    let first = ["receipt", "medical", "shop", "purchase", "items", "list"]

    let merged = SuggestionCleanup.mergedWords(focused: focused, first: first)

    #expect(merged == ["pharmacy", "drugstore", "medicine", "health", "medical", "receipt", "shop", "purchase"])
}

@Test func titleWithAPlaceholderIsDropped() {
    #expect(clean(title: "<store> ID · <company>").title == nil)
    #expect(clean(title: "City Pharmacy receipt >").title == nil)
}

@Test func allLowercaseTitleIsTitleCased() {
    #expect(clean(title: "fitness club plan").title == "Fitness Club Plan")
    #expect(clean(title: "call with the landlord").title == "Call with the Landlord")
}

@Test func lowercaseWordsAreTitleCasedNextToProperOnes() {
    #expect(clean(title: "City Pharmacy receipt").title == "City Pharmacy Receipt")
    #expect(clean(title: "2026 W-2 · Northwind labs").title == "2026 W-2 · Northwind Labs")
}

@Test func shoutedWordsAreTitleCasedButCodesAreKept() {
    #expect(clean(title: "LAKEVIEW UNIVERSITY ID").title == "Lakeview University ID")
    #expect(clean(title: "DMV license · 1099-NEC").title == "DMV License · 1099-NEC")
    #expect(clean(title: "BELL & SONS contact").title == "BELL & SONS Contact")
}

@Test func mixedCaseWordsAreKept() {
    #expect(clean(title: "iPhone receipt · McDonald's").title == "iPhone Receipt · McDonald's")
}

@Test func minorWordsStayLowercaseExceptFirstInAPart() {
    #expect(clean(title: "certificate OF vehicle registration").title == "Certificate of Vehicle Registration")
    #expect(clean(title: "Lease · the Harlow Group").title == "Lease · The Harlow Group")
}

@Test func aPartRepeatingAnEarlierOneIsDropped() {
    #expect(clean(title: "Lakeview University ID · ID").title == "Lakeview University ID")
    #expect(clean(title: "Water bill · Anytown Water · water bill").title == "Water Bill · Anytown Water")
}

@Test func aPartSharingOnlyPartOfAWordIsKept() {
    #expect(clean(title: "Passport · Pass").title == "Passport · Pass")
}
