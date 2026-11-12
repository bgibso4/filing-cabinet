import Core
import Foundation
import Library
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

/// The review's suggestion flow (Plan 5 Task 8), with a scripted suggester and short real waits.
@MainActor
private func review(
    filing: FakeScanSuggester.Outcome<ScanSuggestion> = .arrives(FakeScanSuggester.cityPharmacy(), after: .zero),
    words: FakeScanSuggester.Outcome<[String]> = .arrives(FakeScanSuggester.cityPharmacyWords, after: .zero),
    preselected: BuiltInCollection? = nil,
    reads steps: [FakeTextReader.Step] = [.page(ReviewHarness.pharmacy)],
    suggestionsOn: Bool = true,
    waitLimit: Duration = .seconds(5)
) -> ReviewHarness {
    ReviewHarness(
        preselected: preselected,
        reads: steps,
        suggester: FakeScanSuggester(filing: filing, words: words),
        suggestionsOn: suggestionsOn,
        suggestionWaitLimit: waitLimit
    )
}

/// The suggestion events, in order.
@MainActor
private func suggestionEvents(_ harness: ReviewHarness) -> [AnalyticsEvent] {
    harness.analytics.events.filter {
        switch $0 {
        case .suggestionOutcome, .suggestionChanged: true
        default: false
        }
    }
}

/// Reads, then waits for the suggestion to land (the card stops reading, or the sheet shows).
@MainActor
private func startAndSettle(_ harness: ReviewHarness) async {
    await harness.model.startReading()
    await ReviewHarness.eventually { harness.model.presentation != .card(isReading: true) }
}

// MARK: - Arrival

@Test(.timeLimit(.minutes(1)))
func arrivalFillsTitleAndCollection() async {
    let harness = review()
    #expect(harness.model.presentation == .card(isReading: true))
    #expect(!harness.model.canSave)

    await startAndSettle(harness)

    #expect(harness.model.presentation == .card(isReading: false))
    #expect(harness.model.title == "City Pharmacy receipt")
    #expect(harness.model.collection == .receipts)
    #expect(harness.model.canSave)
    // The model reads what the reader read, and page 1.
    #expect(harness.suggester.filingCalls.map(\.pageTexts) == [["CITY PHARMACY\nTOTAL 12.40"]])
    #expect(harness.suggester.filingCalls.first?.firstPage != nil)
}

@Test(.timeLimit(.minutes(1)))
func typedTitleWins() async {
    let harness = review(filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .milliseconds(50)))
    harness.model.editTitle("Allergy pills")

    await startAndSettle(harness)

    #expect(harness.model.title == "Allergy pills")
    #expect(harness.model.collection == .receipts)
}

@Test(.timeLimit(.minutes(1)))
func pickedCollectionWins() async {
    let harness = review(filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .milliseconds(50)))
    harness.model.choose(.documents)

    await startAndSettle(harness)

    #expect(harness.model.title == "City Pharmacy receipt")
    #expect(harness.model.collection == .documents)
}

@Test(.timeLimit(.minutes(1)))
func preselectedCollectionWinsAndSaveIsOn() async {
    let harness = review(
        filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .milliseconds(50)), preselected: .wallet)
    #expect(harness.model.presentation == .card(isReading: true))
    #expect(harness.model.canSave)

    await startAndSettle(harness)

    #expect(harness.model.title == "City Pharmacy receipt")
    #expect(harness.model.collection == .wallet)
}

@Test(.timeLimit(.minutes(1)))
func openedSheetStillFills() async {
    let harness = review(filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .milliseconds(50)))
    harness.model.openSheet()
    #expect(harness.model.presentation == .sheet)

    await harness.model.startReading()
    await ReviewHarness.eventually { harness.model.suggestionAnnouncement != nil }

    #expect(harness.model.presentation == .sheet)
    #expect(harness.model.title == "City Pharmacy receipt")
    #expect(harness.model.collection == .receipts)
}

@Test(.timeLimit(.minutes(1)))
func unknownCollectionIDIsIgnored() async {
    let harness = review(filing: .arrives(ScanSuggestion(title: "Tax form", collectionID: "taxes"), after: .zero))

    await startAndSettle(harness)

    #expect(harness.model.title == "Tax form")
    #expect(harness.model.collection == nil)
    #expect(harness.model.suggestionAnnouncement == "Suggested: Tax form")
}

@Test(.timeLimit(.minutes(1)))
func announcementNamesTitleAndCollection() async {
    let harness = review()
    #expect(harness.model.suggestionAnnouncement == nil)

    await startAndSettle(harness)

    #expect(harness.model.suggestionAnnouncement == "Suggested: City Pharmacy receipt, Receipts")
}

@Test(.timeLimit(.minutes(1)))
func failedSuggestionShowsTheSheet() async {
    let harness = review(filing: .fails)

    await startAndSettle(harness)

    #expect(harness.model.presentation == .sheet)
    #expect(harness.model.title == "City Pharmacy")
    #expect(harness.model.suggestionAnnouncement == nil)
    #expect(suggestionEvents(harness) == [.suggestionOutcome(.failed)])
}

// MARK: - Too slow

@Test(.timeLimit(.minutes(1)))
func timeoutGrowsTheSheetWithTheRuleTitle() async {
    let harness = review(filing: .never, waitLimit: .milliseconds(50))

    await startAndSettle(harness)

    #expect(harness.model.presentation == .sheet)
    #expect(harness.model.title == "City Pharmacy")
    #expect(harness.model.collection == nil)
    #expect(suggestionEvents(harness) == [.suggestionOutcome(.timedOut)])
}

@Test(.timeLimit(.minutes(1)))
func lateSuggestionAfterTimeoutIsDropped() async throws {
    let harness = review(
        filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .milliseconds(300)), waitLimit: .milliseconds(50))

    await startAndSettle(harness)
    try await Task.sleep(for: .milliseconds(400))

    #expect(harness.model.presentation == .sheet)
    #expect(harness.model.title == "City Pharmacy")
    #expect(harness.model.collection == nil)
    #expect(harness.model.suggestionAnnouncement == nil)
    #expect(suggestionEvents(harness) == [.suggestionOutcome(.timedOut)])
}

// MARK: - Rescan

@Test(.timeLimit(.minutes(1)))
func rescanCancelsTheOldSuggestion() async throws {
    let harness = review(
        filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .milliseconds(200)),
        reads: [.page(ReviewHarness.pharmacy), .page(ReviewHarness.market)]
    )
    await harness.model.startReading()
    await ReviewHarness.eventually { harness.suggester.filingCalls.count == 1 }

    harness.model.replacePages([ReviewHarness.page2])
    await ReviewHarness.eventually { harness.model.suggestionAnnouncement != nil }
    try await Task.sleep(for: .milliseconds(300))

    #expect(harness.suggester.filingCalls.map(\.pageTexts) == [["CITY PHARMACY\nTOTAL 12.40"], ["CORNER MARKET"]])
    #expect(suggestionEvents(harness) == [.suggestionOutcome(.arrived)])
    #expect(harness.model.title == "City Pharmacy receipt")
}

// MARK: - Save

@Test(.timeLimit(.minutes(1)))
func saveBeforeSuggestionAddsOnlyWords() async throws {
    let harness = review(filing: .never, preselected: .receipts)
    await harness.model.startReading()

    let saved = try #require(await harness.model.save())

    #expect(harness.library.saved.first?.title == "City Pharmacy")
    #expect(await ReviewHarness.eventually { harness.library.searchWords()[saved.id] != [] })
    #expect(harness.library.searchWords()[saved.id] == FakeScanSuggester.cityPharmacyWords)
    #expect(harness.library.scansNeedingWords(version: ScanSuggestion.promptVersion).isEmpty)
    // Title and collection are never changed after Save.
    #expect(harness.library.scans.map(\.title) == ["City Pharmacy"])
    #expect(harness.library.scans.map(\.collection) == [.receipts])
    #expect(suggestionEvents(harness).isEmpty)
}

@Test(.timeLimit(.minutes(1)))
func saveStartsTheWordsCall() async throws {
    let harness = review()
    await startAndSettle(harness)

    let saved = try #require(await harness.model.save())

    #expect(await ReviewHarness.eventually { harness.library.searchWords()[saved.id] != [] })
    #expect(harness.library.searchWords()[saved.id] == FakeScanSuggester.cityPharmacyWords)
    #expect(harness.library.scansNeedingWords(version: ScanSuggestion.promptVersion).isEmpty)
    let call = try #require(harness.suggester.wordsCalls.first)
    #expect(call.title == "City Pharmacy receipt")
    #expect(call.collectionName == "Receipts")
    #expect(call.input.pageTexts == ["CITY PHARMACY\nTOTAL 12.40"])
    #expect(harness.library.scans.map(\.title) == ["City Pharmacy receipt"])
    #expect(harness.backgroundTime.begun == ["Search words"])
}

@Test(.timeLimit(.minutes(1)))
func slowReadingStillGetsWordsAfterSave() async throws {
    let harness = ReviewHarness(
        preselected: .receipts,
        reads: [.page(ReviewHarness.pharmacy, delay: .milliseconds(200))],
        readingWaitLimit: .milliseconds(10),
        suggester: FakeScanSuggester(
            filing: .never, words: .arrives(FakeScanSuggester.cityPharmacyWords, after: .zero)),
        suggestionsOn: true
    )

    let saved = try #require(await harness.model.save())

    #expect(await ReviewHarness.eventually { harness.library.searchWords()[saved.id] != [] })
    #expect(harness.suggester.wordsCalls.map(\.input.pageTexts) == [["CITY PHARMACY\nTOTAL 12.40"]])
}

@Test(.timeLimit(.minutes(1)))
func wordsFailureLeavesTheScanForThePass() async throws {
    let harness = review(words: .fails)
    await startAndSettle(harness)

    let saved = try #require(await harness.model.save())
    await ReviewHarness.eventually { harness.backgroundTime.ended == 1 }

    #expect(harness.suggester.wordsCalls.count == 1)
    #expect(harness.library.searchWords()[saved.id] == [])
    #expect(harness.library.scansNeedingWords(version: ScanSuggestion.promptVersion) == [saved.id])
}

@Test(.timeLimit(.minutes(1)))
func analyticsCarryNoContent() async throws {
    let harness = review()
    await startAndSettle(harness)
    harness.model.choose(.documents)

    _ = try #require(await harness.model.save())

    #expect(
        suggestionEvents(harness) == [
            .suggestionOutcome(.arrived), .suggestionChanged(title: false, collection: true),
        ])
}

// MARK: - No suggestions

@Test(.timeLimit(.minutes(1)))
func unavailableShowsTheSheetAtOnce() async throws {
    let harness = ReviewHarness(preselected: .receipts, suggestionsOn: true)
    #expect(harness.model.presentation == .sheet)

    await harness.model.startReading()
    _ = try #require(await harness.model.save())
    try await Task.sleep(for: .milliseconds(50))

    #expect(harness.model.title == "City Pharmacy")
    #expect(harness.suggester.filingCalls.isEmpty)
    #expect(harness.suggester.wordsCalls.isEmpty)
    #expect(suggestionEvents(harness) == [.suggestionOutcome(.unavailable)])
}

@Test(.timeLimit(.minutes(1)))
func switchOffShowsTheSheet() async throws {
    let harness = review(preselected: .receipts, suggestionsOn: false)
    #expect(harness.model.presentation == .sheet)

    await harness.model.startReading()
    _ = try #require(await harness.model.save())
    try await Task.sleep(for: .milliseconds(50))

    #expect(harness.model.title == "City Pharmacy")
    #expect(harness.suggester.filingCalls.isEmpty)
    #expect(harness.suggester.wordsCalls.isEmpty)
    #expect(suggestionEvents(harness).isEmpty)
}

@Test(.timeLimit(.minutes(1)))
func discardStopsTheWait() async throws {
    let harness = review(filing: .never, waitLimit: .milliseconds(50))
    await harness.model.startReading()

    harness.model.discard()
    try await Task.sleep(for: .milliseconds(150))

    #expect(suggestionEvents(harness).isEmpty)
}

@Test(.timeLimit(.minutes(1)))
func failedSaveFromAReadingCardShowsTheSheet() async {
    let harness = review(filing: .never, preselected: .receipts)
    await harness.model.startReading()
    harness.library.failNextSave = .diskFull

    #expect(await harness.model.save() == nil)

    #expect(harness.model.saveAlert != nil)
    #expect(harness.model.presentation == .sheet)
}

@Test(.timeLimit(.minutes(1)))
func rescanAfterLandingResetsSuggestedFields() async {
    let harness = review(reads: [.page(ReviewHarness.pharmacy), .page(ReviewHarness.market)])
    await startAndSettle(harness)
    #expect(harness.model.collection == .receipts)

    harness.model.replacePages([ReviewHarness.page2])
    await harness.model.startReading()

    // The wait is over, so the new pages get the text rule and the collection is unchosen again.
    #expect(harness.model.title == "Corner Market")
    #expect(harness.model.collection == nil)
    #expect(harness.suggester.filingCalls.count == 1)
}

@Test(.timeLimit(.minutes(1)))
func rescanKeepsWhatTheUserChose() async {
    let harness = review(
        filing: .arrives(FakeScanSuggester.cityPharmacy(), after: .milliseconds(50)),
        reads: [.page(ReviewHarness.pharmacy), .page(ReviewHarness.market)]
    )
    harness.model.choose(.documents)
    await startAndSettle(harness)
    #expect(harness.model.title == "City Pharmacy receipt")

    harness.model.editTitle("Allergy pills")
    harness.model.replacePages([ReviewHarness.page2])
    await harness.model.startReading()

    #expect(harness.model.title == "Allergy pills")
    #expect(harness.model.collection == .documents)
}

@Test(.timeLimit(.minutes(1)))
func rescanFromInsideACollectionKeepsIt() async {
    let harness = review(preselected: .wallet, reads: [.page(ReviewHarness.pharmacy), .page(ReviewHarness.market)])
    await startAndSettle(harness)

    harness.model.replacePages([ReviewHarness.page2])
    await harness.model.startReading()

    #expect(harness.model.collection == .wallet)
    #expect(harness.model.title == "Corner Market")
}
