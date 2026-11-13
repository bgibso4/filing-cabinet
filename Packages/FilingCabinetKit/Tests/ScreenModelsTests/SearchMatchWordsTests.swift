import Testing

@testable import ScreenModels

/// Matches `query` the way Search does, with the scan's hidden `words`.
private func hit(_ query: String, title: String = "Scan", text: String = "", words: [String]) -> SearchHit? {
    SearchMatch.match(
        title: SearchMatch.Folded(title),
        text: SearchMatch.FoldedText(text),
        words: SearchMatch.hiddenWords(words),
        terms: SearchMatch.terms(query).map(SearchMatch.Folded.init))
}

@Test func wordPrefixMatches() {
    let found = hit("lic", words: ["license"])
    #expect(found != nil)
    #expect(found?.matchedOnlyHiddenWords == true)
}

@Test func wordMustStartWithTerm() {
    #expect(hit("cense", words: ["license"]) == nil)
}

@Test func termMatchesAnyPartOfAPhrase() {
    #expect(hit("lic", words: ["driver license"]) != nil)
    #expect(hit("driv", words: ["driver license"]) != nil)
    #expect(hit("cense", words: ["driver license"]) == nil)
    #expect(hit("river", words: ["driver license"]) == nil)
}

@Test func pluralTermFindsSingularWord() {
    #expect(hit("taxes", words: ["tax"]) != nil)
    #expect(hit("ids", words: ["ID"]) != nil)
    #expect(hit("receipts", words: ["receipt"]) != nil)
    // What is left must be 2 characters or more: "is" is not "i".
    #expect(hit("is", words: ["i"]) == nil)
    #expect(hit("as", words: ["a"]) == nil)
}

@Test func pluralStemMustMatchAWholeWord() {
    #expect(hit("bus", words: ["budget"]) == nil)
    #expect(hit("taxes", words: ["tax"]) != nil)
    #expect(hit("taxes", words: ["taxi"]) == nil)
    #expect(hit("taxes", words: ["tax return"]) != nil)
    #expect(hit("taxes", words: ["income tax"]) != nil)
    // The stem is "bu": only a whole part "bu" has it. The term itself still starts parts.
    #expect(hit("bus", words: ["bu"]) != nil)
    #expect(hit("bus", words: ["bus stop"]) != nil)
}

@Test func termMustNotSpanTwoWords() {
    #expect(hit("cardi", words: ["card", "id"]) == nil)
}

@Test func whitespaceInWordsIsOneSpace() {
    #expect(hit("license", words: ["driver   license"]) != nil)
    #expect(hit("license", words: ["driver\nlicense"]) != nil)
    #expect(hit("taxes", words: ["  tax\t"]) != nil)
    #expect(hit("driver license", words: ["driver \t license"]) != nil)
}

@Test func foldsCaseAndAccentsInWords() {
    #expect(hit("cafe", words: ["Café"]) != nil)
    #expect(hit("ID", words: ["id"]) != nil)
}

@Test func pageTextBeatsWord() {
    let found = hit("id", text: "Photo ID card", words: ["ID"])
    #expect(found?.matchedOnlyHiddenWords == false)
    #expect(found?.snippet == "Photo ID card")
}

@Test func titleBeatsWord() {
    let found = hit("id", title: "My ID", text: "Name\nAddress", words: ["ID"])
    #expect(found?.matchedOnlyHiddenWords == false)
    #expect(found?.titleMatches == true)
    #expect(found?.snippet == "Name")
}

@Test func everyTermMustMatchSomewhere() {
    let found = hit("ID sample", text: "A sample page", words: ["ID"])
    #expect(found != nil)
    #expect(found?.snippet == "A sample page")
    #expect(hit("ID missing", text: "A sample page", words: ["ID"]) == nil)
}

@Test func noWordsBehavesAsPlanFour() {
    #expect(hit("id", words: []) == nil)
    #expect(hit("renew", title: "Gym", text: "Renews monthly", words: []) != nil)
}
