import TestSupport
import Testing

@testable import Understanding

private let input = SuggestionInput(
    pageTexts: ["CITY PHARMACY"], firstPage: nil, collections: SuggestionCollection.builtIns)

@Test func arrivesAfterItsDelay() async {
    let delay = Duration.milliseconds(50)
    let fake = FakeScanSuggester(.arrives(FakeScanSuggester.cityPharmacy(), after: delay))
    let start = ContinuousClock.now

    let suggestion = await fake.suggest(input)

    #expect(ContinuousClock.now - start >= delay)
    #expect(suggestion == FakeScanSuggester.cityPharmacy())
    #expect(fake.availability == .available)
    #expect(fake.calls.map(\.pageTexts) == [["CITY PHARMACY"]])
}

@Test func neverAnswersUntilCancelled() async {
    let fake = FakeScanSuggester(.never)
    let task = Task { await fake.suggest(input) }

    task.cancel()

    #expect(await task.value == nil)
}

@Test func unavailableNeverSuggests() async {
    let fake = FakeScanSuggester(.unavailable)

    #expect(fake.availability == .unavailable)
    #expect(await fake.suggest(input) == nil)
}

@Test func cityPharmacyIsAReceipt() {
    let suggestion = FakeScanSuggester.cityPharmacy()

    #expect(suggestion.title == "City Pharmacy receipt")
    #expect(suggestion.collectionID == "receipts")
    #expect(suggestion.searchWords == ["receipt", "pharmacy", "purchase"])
}

@Test func prewarmIsRecorded() {
    let fake = FakeScanSuggester(.never)

    fake.prewarm(collections: SuggestionCollection.builtIns)
    fake.prewarm(collections: [])

    #expect(fake.prewarms.map { $0.map(\.id) } == [SuggestionCollection.builtIns.map(\.id), []])
}
