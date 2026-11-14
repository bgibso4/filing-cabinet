import Testing

@testable import Understanding

private let builtIns = SuggestionCollection.builtIns

private func clean(title: String? = nil, collection: String? = nil) -> ScanSuggestion {
    SuggestionCleanup.clean(title: title, collectionID: collection, allowed: builtIns)
}

private func clean(words: [String]) -> [String] {
    SuggestionCleanup.cleanWords(words)
}

@Test func knownCollectionIsKept() {
    #expect(clean(collection: "receipts").collectionID == "receipts")
}

@Test func unknownCollectionIsDropped() {
    #expect(clean(collection: "taxes").collectionID == nil)
    #expect(clean(collection: nil).collectionID == nil)
}

@Test func titleIsTrimmedAndCollapsed() {
    #expect(clean(title: "  City   Pharmacy\n receipt ").title == "City Pharmacy Receipt")
}

@Test func titleIsCutAtFortyOnAWord() {
    let title = clean(title: "Northwind Property Management lease renewal for unit 4B").title

    #expect(title == "Northwind Property Management Lease")
    #expect((title?.count ?? 0) <= 40)
}

@Test func titleOfOneLongWordIsCutAtForty() {
    #expect(clean(title: String(repeating: "a", count: 60)).title == "A" + String(repeating: "a", count: 39))
}

@Test func titleOfExactlyFortyIsKept() {
    let forty = "Coat Check Ticket From the Grand Theatre"
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

    let cleaned = clean(words: ["Receipt", "receipt", "RECEIPT"] + words)

    #expect(cleaned.count == 8)
    #expect(cleaned.first == "receipt")
    #expect(Set(cleaned.map { $0.lowercased() }).count == 8)
}

@Test func allCapsWordsKeepTheirCase() {
    #expect(
        clean(words: ["ID", "W-2", "Pharmacy", "DMV", "iPhone"]) == [
            "ID", "W-2", "pharmacy", "DMV", "iphone",
        ])
}

@Test func emptyWordsAreDropped() {
    #expect(clean(words: ["", "  ", "\n", "license"]) == ["license"])
}

@Test func overlongWordsAreDroppedAndSpacesCollapsed() {
    #expect(clean(words: [String(repeating: "x", count: 41), " parking   stub "]) == ["parking stub"])
}

@Test func titleLosesLeadingAndTrailingSeparators() {
    #expect(clean(title: "W-2 Wage and Tax Statement 2026 · ").title == "W-2 Wage and Tax Statement 2026")
    #expect(clean(title: " - Coat check ticket:").title == "Coat Check Ticket")
    #expect(clean(title: "· , City Pharmacy receipt ,").title == "City Pharmacy Receipt")
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

@Test func titleWithAPlaceholderIsDropped() {
    #expect(clean(title: "<store> ID · <company>").title == nil)
    #expect(clean(title: "City Pharmacy receipt >").title == nil)
}

@Test func everyWordGetsACapital() {
    #expect(clean(title: "City Pharmacy receipt").title == "City Pharmacy Receipt")
    #expect(clean(title: "driver's license").title == "Driver's License")
    #expect(clean(title: "Biology notes · cell respiration").title == "Biology Notes · Cell Respiration")
    #expect(clean(title: "fitness club plan").title == "Fitness Club Plan")
}

@Test func codesAndMixedCaseWordsAreKeptAsWritten() {
    #expect(clean(title: "2025 W-2 · Northwind").title == "2025 W-2 · Northwind")
    #expect(clean(title: "1099-NEC · northwind").title == "1099-NEC · Northwind")
    #expect(clean(title: "follow-up letter").title == "follow-up Letter")
    #expect(clean(title: "iPhone receipt · McDonald's").title == "iPhone Receipt · McDonald's")
}

@Test func knownAcronymsAreInCapitals() {
    #expect(clean(title: "dmv license").title == "DMV License")
    #expect(clean(title: "Lakeview University · student id").title == "Lakeview University · Student ID")
    #expect(clean(title: "Cedar Court Hoa, Llc").title == "Cedar Court HOA, LLC")
    #expect(clean(title: "DMV RENEWAL NOTICE").title == "DMV Renewal Notice")
}

@Test func allCapsWordsAreCapitalised() {
    #expect(clean(title: "HARBOR GAS").title == "Harbor Gas")
    #expect(clean(title: "HARBOR GAS receipt").title == "Harbor Gas Receipt")
    #expect(clean(title: "BRIGHTPATH TAX SERVICE · Federal return").title == "Brightpath Tax Service · Federal Return")
    #expect(clean(title: "Northwind LABS Staff ID").title == "Northwind Labs Staff ID")
    #expect(clean(title: "PORTLAND, OR").title == "Portland, Or")
    #expect(clean(title: "MCDONALD'S").title == "Mcdonald's")
    #expect(clean(title: "W-2 WAGE STATEMENT").title == "W-2 Wage Statement")
}

@Test func smallWordsWrittenLowercaseStayLowercaseInsideAPart() {
    #expect(clean(title: "notes of the meeting").title == "Notes of the Meeting")
    #expect(clean(title: "the lease · terms and conditions").title == "The Lease · Terms and Conditions")
    #expect(clean(title: "Notes Of The Meeting").title == "Notes Of The Meeting")
    #expect(clean(title: "Bill · for March").title == "Bill · For March")
}

@Test func spacedDashBetweenPartsBecomesAMiddot() {
    #expect(clean(title: "Studio Fern - Business card").title == "Studio Fern · Business Card")
    #expect(clean(title: "Kickoff meeting – Nov 4").title == "Kickoff Meeting · Nov 4")
    #expect(clean(title: "Anytown Water Works, Bill").title == "Anytown Water Works, Bill")
    #expect(clean(title: "W-2 · Northwind").title == "W-2 · Northwind")
}

@Test func aPartRepeatingAnEarlierOneIsDropped() {
    #expect(clean(title: "Lakeview University ID · ID").title == "Lakeview University ID")
    #expect(clean(title: "Water bill · Anytown Water · water bill").title == "Water Bill · Anytown Water")
    #expect(clean(title: "Card · Credit Card").title == "Card · Credit Card")
}

@Test func aPartSharingOnlyPartOfAWordIsKept() {
    #expect(clean(title: "Passport · Pass").title == "Passport · Pass")
}

private func composed(_ name: String?, _ kind: String?) -> String? {
    SuggestionCleanup.composedTitle(name: name, kind: kind)
}

@Test func nameAndKindJoin() {
    #expect(composed("InBody", "Report") == "InBody Report")
}

@Test func noNameGivesKind() {
    #expect(composed("", "Library Card") == "Library Card")
    #expect(composed(nil, "Library Card") == "Library Card")
}

@Test func nameEndingInKindIsNotRepeated() {
    #expect(composed("City Pharmacy Receipt", "Receipt") == "City Pharmacy Receipt")
    #expect(composed("City Pharmacy RECEIPT", "receipt") == "City Pharmacy RECEIPT")
    // Only a whole word counts: "Receipts" does not end in the word "Receipt".
    #expect(composed("City Receipts", "Receipt") == "City Receipts Receipt")
}

@Test func nameEqualToKindIsDropped() {
    #expect(composed("Receipt", "receipt") == "receipt")
}

@Test func noKindGivesName() {
    #expect(composed("Maple Street Hardware", "") == "Maple Street Hardware")
    #expect(composed("Maple Street Hardware", nil) == "Maple Street Hardware")
}

@Test func bothEmptyIsNil() {
    #expect(composed("", "") == nil)
    #expect(composed("  \n ", "   ") == nil)
    #expect(composed(nil, nil) == nil)
}

@Test func spacingIsTrimmedAndCollapsed() {
    #expect(composed("  InBody  ", " Body   Scan ") == "InBody Body Scan")
}

@Test func longNameIsCutBeforeTheKind() {
    let name = "Northwind Property Management Services Inc"
    #expect(name.count > 40)

    let title = SuggestionCleanup.composedTitle(name: name, kind: "Receipt")

    #expect(title == "Northwind Property Management Receipt")
    #expect(clean(title: title).title?.hasSuffix("Receipt") == true)
    #expect((clean(title: title).title?.count ?? 99) <= 40)
}

@Test func aNameOfOneLongWordLeavesTheKindAlone() {
    let title = composed(String(repeating: "a", count: 45), "Receipt")

    #expect(title == "Receipt")
}
