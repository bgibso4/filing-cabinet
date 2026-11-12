import Testing

@testable import Understanding

/// The eval's timeout race on fakes; no model runs here.
struct TimedSuggestionTests {
    /// Answers after `delay`, or nil when cancelled first.
    private struct SlowSuggester: ScanSuggester {
        let delay: Duration

        var availability: SuggesterAvailability { .available }

        func suggest(_ input: SuggestionInput) async -> ScanSuggestion? {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return nil
            }
            return ScanSuggestion(title: "Answer", collectionID: nil, searchWords: [])
        }
    }

    private static let input = SuggestionInput(pageTexts: ["text"], firstPage: nil, collections: [])

    @Test func answerInTimeIsKept() async {
        let answer = await TimedSuggestion.suggest(
            SlowSuggester(delay: .milliseconds(1)), Self.input, limit: .seconds(10))

        #expect(answer.suggestion?.title == "Answer")
        #expect(!answer.timedOut)
        #expect(answer.milliseconds < 10_000)
    }

    @Test func slowCallIsCancelledAtTheLimit() async {
        let start = ContinuousClock.now
        let answer = await TimedSuggestion.suggest(
            SlowSuggester(delay: .seconds(60)), Self.input, limit: .milliseconds(50))

        #expect(answer.suggestion == nil)
        #expect(answer.timedOut)
        #expect(ContinuousClock.now - start < .seconds(5))
    }
}
