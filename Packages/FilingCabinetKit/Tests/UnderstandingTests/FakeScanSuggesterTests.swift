import TestSupport
import Testing

@testable import Understanding

private let input = SuggestionInput(
    pageTexts: ["CITY PHARMACY"], firstPage: nil, collections: SuggestionCollection.builtIns)

@Test func filingArrivesAfterItsDelay() async {
    let delay = Duration.milliseconds(50)
    let fake = FakeScanSuggester(filing: .arrives(FakeScanSuggester.cityPharmacy(), after: delay))
    let start = ContinuousClock.now

    let suggestion = await fake.suggestFiling(input)

    #expect(ContinuousClock.now - start >= delay)
    #expect(suggestion == FakeScanSuggester.cityPharmacy())
    #expect(fake.availability == .available)
    #expect(fake.filingCalls.map(\.pageTexts) == [["CITY PHARMACY"]])
}

@Test func wordsAreScriptedApartFromFiling() async {
    let words = FakeScanSuggester.cityPharmacyWords
    let fake = FakeScanSuggester(filing: .fails, words: .arrives(words, after: .zero))

    #expect(await fake.suggestFiling(input) == nil)
    #expect(await fake.suggestWords(input, title: "City Pharmacy", collectionName: "Receipts") == words)
    #expect(fake.wordsCalls.map(\.title) == ["City Pharmacy"])
    #expect(fake.wordsCalls.map(\.collectionName) == ["Receipts"])
}

@Test func neverAnswersUntilCancelled() async {
    let fake = FakeScanSuggester(filing: .never)
    let task = Task { await fake.suggestFiling(input) }

    task.cancel()

    #expect(await task.value == nil)
}

@Test func unavailableNeverSuggests() async {
    let fake = FakeScanSuggester.unavailable()

    #expect(fake.availability == .unavailable)
    #expect(await fake.suggestFiling(input) == nil)
    #expect(await fake.suggestWords(input, title: "A", collectionName: "B") == nil)
}

@Test func cityPharmacyIsAReceipt() {
    let suggestion = FakeScanSuggester.cityPharmacy()

    #expect(suggestion.title == "City Pharmacy Receipt")
    #expect(suggestion.collectionID == "receipts")
    #expect(FakeScanSuggester.cityPharmacyWords == ["receipt", "pharmacy", "purchase"])
}

@Test func prewarmIsRecorded() {
    let fake = FakeScanSuggester(filing: .never)

    fake.prewarm(collections: SuggestionCollection.builtIns)
    fake.prewarm(collections: [])

    #expect(fake.prewarms.map { $0.map(\.id) } == [SuggestionCollection.builtIns.map(\.id), []])
}
