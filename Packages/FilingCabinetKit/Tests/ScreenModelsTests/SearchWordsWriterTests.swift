import Core
import Foundation
import Library
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

/// A saved scan to write words for: Oct 12, 2026, so it is in the library, not Trash.
@MainActor
private func savedScan(in library: FakeLibrary) async throws -> ScanID {
    let id = ScanID()
    try await library.save(
        ScanDraft(
            id: id,
            title: "City Pharmacy",
            collection: .receipts,
            scannedAt: ReviewHarness.now,
            expiryOverride: nil,
            pages: [ReviewHarness.page1],
            searchText: "CITY PHARMACY"
        ))
    return id
}

private let input = SuggestionInput(
    searchText: "CITY PHARMACY", firstPage: nil, collections: SuggestionCollection.builtIns)

@Test(.timeLimit(.minutes(1)))
func wordsAreStoredWithThePromptVersion() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let suggester = FakeScanSuggester(
        filing: .fails, words: .arrives(FakeScanSuggester.cityPharmacyWords, after: .zero))
    let writer = SearchWordsWriter(suggester: suggester, library: library, backgroundTime: FakeBackgroundTime())

    await writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts").value

    #expect(library.searchWords()[id] == FakeScanSuggester.cityPharmacyWords)
    #expect(library.scansNeedingWords(version: ScanSuggestion.promptVersion).isEmpty)
    #expect(suggester.wordsCalls.map(\.title) == ["City Pharmacy"])
    #expect(suggester.wordsCalls.map(\.collectionName) == ["Receipts"])
}

@Test(.timeLimit(.minutes(1)))
func leavingTheAppAsksForBackgroundTime() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let suggester = FakeScanSuggester(
        filing: .fails, words: .arrives(FakeScanSuggester.cityPharmacyWords, after: .milliseconds(100)))
    let time = FakeBackgroundTime()
    let writer = SearchWordsWriter(suggester: suggester, library: library, backgroundTime: time)

    let task = writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts")

    // Asked for as the call starts, so leaving the app mid-call is covered; ended once it is done.
    #expect(time.begun == ["Search words"])
    #expect(time.ended == 0)
    await task.value
    #expect(await ReviewHarness.eventually { time.ended == 1 })
}

@Test(.timeLimit(.minutes(1)))
func runningOutOfBackgroundTimeCancelsTheCall() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let time = FakeBackgroundTime()
    let writer = SearchWordsWriter(
        suggester: FakeScanSuggester(filing: .fails, words: .never), library: library, backgroundTime: time)

    let task = writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts")
    time.expire()
    await task.value

    #expect(library.searchWords()[id] == [])
    #expect(library.scansNeedingWords(version: ScanSuggestion.promptVersion) == [id])
}

@Test(.timeLimit(.minutes(1)))
func aHungCallIsCancelledAtItsLimit() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let writer = SearchWordsWriter(
        suggester: FakeScanSuggester(filing: .fails, words: .never),
        library: library,
        backgroundTime: FakeBackgroundTime(),
        callLimit: .milliseconds(50)
    )

    await writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts").value

    #expect(library.scansNeedingWords(version: ScanSuggestion.promptVersion) == [id])
}

@Test(.timeLimit(.minutes(1)))
func aCallIgnoringCancellationStillEndsAtTheLimit() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let time = FakeBackgroundTime()
    let writer = SearchWordsWriter(
        suggester: FakeScanSuggester(filing: .fails, words: .hangsIgnoringCancellation),
        library: library,
        backgroundTime: time,
        callLimit: .milliseconds(50)
    )
    let start = ContinuousClock.now

    await writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts").value

    #expect(ContinuousClock.now - start < .seconds(5))
    #expect(await ReviewHarness.eventually { time.ended == 1 })
    #expect(library.scansNeedingWords(version: ScanSuggestion.promptVersion) == [id])
}

@Test(.timeLimit(.minutes(1)))
func runningOutOfTimeEndsACallIgnoringCancellation() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let time = FakeBackgroundTime()
    let writer = SearchWordsWriter(
        suggester: FakeScanSuggester(filing: .fails, words: .hangsIgnoringCancellation),
        library: library,
        backgroundTime: time
    )

    let task = writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts")
    time.expire()
    await task.value

    #expect(library.scansNeedingWords(version: ScanSuggestion.promptVersion) == [id])
}

/// The background pass waits behind a words call after Save, so it reads `isWriting`.
@Test(.timeLimit(.minutes(1)))
func isWritingUntilTheCallEnds() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let writer = SearchWordsWriter(
        suggester: FakeScanSuggester(filing: .fails, words: .arrives(["receipt"], after: .milliseconds(50))),
        library: library,
        backgroundTime: FakeBackgroundTime())
    #expect(!writer.isWriting)

    let task = writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts")
    #expect(writer.isWriting)
    await task.value

    #expect(await ReviewHarness.eventually { !writer.isWriting })
}

/// While the next review's filing call runs, a words call waits for it (holding background time meanwhile); it starts
/// once that call ends.
@Test(.timeLimit(.minutes(1)))
func aWordsCallWaitsForTheFilingCall() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let suggester = FakeScanSuggester(filing: .fails, words: .arrives(["receipt"], after: .zero))
    let time = FakeBackgroundTime()
    let writer = SearchWordsWriter(
        suggester: suggester,
        library: library,
        backgroundTime: time,
        callLimit: .seconds(30),
        filingRecheck: .milliseconds(10))
    writer.isFilingUnderWay = true

    let task = writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts")
    try await Task.sleep(for: .milliseconds(100))
    #expect(suggester.wordsCalls.isEmpty)
    #expect(writer.isWriting)
    #expect(time.begun == ["Search words"])

    writer.isFilingUnderWay = false
    await task.value
    #expect(suggester.wordsCalls.count == 1)
    #expect(library.searchWords()[id] == ["receipt"])
}

/// Background time running out while the words call waits ends it without asking the model.
@Test(.timeLimit(.minutes(1)))
func runningOutOfTimeWhileWaitingAsksNothing() async throws {
    let library = FakeLibrary()
    let id = try await savedScan(in: library)
    let suggester = FakeScanSuggester(filing: .fails, words: .arrives(["receipt"], after: .zero))
    let time = FakeBackgroundTime()
    let writer = SearchWordsWriter(
        suggester: suggester,
        library: library,
        backgroundTime: time,
        callLimit: .seconds(30),
        filingRecheck: .milliseconds(10))
    writer.isFilingUnderWay = true

    let task = writer.write(for: id, input: input, title: "City Pharmacy", collectionName: "Receipts")
    time.expire()
    await task.value

    #expect(suggester.wordsCalls.isEmpty)
    #expect(library.scansNeedingWords(version: ScanSuggestion.promptVersion) == [id])
}
