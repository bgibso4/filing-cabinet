import Core
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

/// A review's filing call holds back a words call after the last Save until it ends, so the two never share the model.
@MainActor
private func review(filing: FakeScanSuggester.Outcome<ScanSuggestion>, waitLimit: Duration = .seconds(5))
    -> ReviewHarness
{
    ReviewHarness(
        suggester: FakeScanSuggester(filing: filing, words: .fails),
        suggestionsOn: true,
        suggestionWaitLimit: waitLimit)
}

@Test(.timeLimit(.minutes(1)))
func theFilingCallHoldsWordsCallsUntilTheReviewEnds() async {
    let harness = review(filing: .never)
    #expect(!harness.wordsWriter.isFilingUnderWay)
    await harness.model.startReading()
    #expect(harness.wordsWriter.isFilingUnderWay)

    harness.model.discard()

    #expect(!harness.wordsWriter.isFilingUnderWay)
}

@Test(.timeLimit(.minutes(1)))
func aLandedSuggestionLetsWordsCallsGo() async {
    let harness = review(filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .zero))
    await harness.model.startReading()

    #expect(await ReviewHarness.eventually { harness.model.presentation == .card(isReading: false) })
    #expect(!harness.wordsWriter.isFilingUnderWay)
}

@Test(.timeLimit(.minutes(1)))
func aTimeoutLetsWordsCallsGo() async {
    let harness = review(filing: .never, waitLimit: .milliseconds(50))
    await harness.model.startReading()

    #expect(await ReviewHarness.eventually { harness.model.presentation == .sheet })
    #expect(!harness.wordsWriter.isFilingUnderWay)
}
