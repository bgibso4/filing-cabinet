import Synchronization
import Understanding

/// Test double, also built by the app for `-Suggestions`: answers every `suggestFiling` with one scripted outcome and
/// every `suggestWords` with another.
public final class FakeScanSuggester: ScanSuggester {
    public enum Outcome<Answer: Sendable>: Sendable {
        /// Return this answer after `after`; nil if cancelled first.
        case arrives(Answer, after: Duration)
        /// Return nil at once: the model failed.
        case fails
        /// Wait until cancelled, then return nil.
        case never
        /// Never answer, even when cancelled: the model call once seen to hang for 10+ minutes.
        case hangsIgnoringCancellation
    }

    /// Long enough that only a cancel ends `.never` in any test.
    private static let forever = Duration.seconds(86_400)

    private let isAvailable: Bool
    private let filing: Outcome<ScanSuggestion>
    private let words: Outcome<[String]>
    private let recordedFilings = Mutex<[SuggestionInput]>([])
    private let recordedWords = Mutex<[WordsCall]>([])
    private let recordedPrewarms = Mutex<[[SuggestionCollection]]>([])

    /// One `suggestWords` call.
    package struct WordsCall: Sendable {
        package let input: SuggestionInput
        package let title: String
        package let collectionName: String
    }

    public init(filing: Outcome<ScanSuggestion>, words: Outcome<[String]> = .fails) {
        isAvailable = true
        self.filing = filing
        self.words = words
    }

    /// Reports unavailable, and never answers.
    public static func unavailable() -> FakeScanSuggester {
        FakeScanSuggester(isAvailable: false)
    }

    private init(isAvailable: Bool) {
        self.isAvailable = isAvailable
        filing = .fails
        words = .fails
    }

    /// Every input `suggestFiling` was called with, in order.
    package var filingCalls: [SuggestionInput] { recordedFilings.withLock { $0 } }

    /// Every `suggestWords` call, in order.
    package var wordsCalls: [WordsCall] { recordedWords.withLock { $0 } }

    /// The collections of every `prewarm` call, in order.
    package var prewarms: [[SuggestionCollection]] { recordedPrewarms.withLock { $0 } }

    public var availability: SuggesterAvailability { isAvailable ? .available : .unavailable }

    public func suggestFiling(_ input: SuggestionInput) async -> ScanSuggestion? {
        recordedFilings.withLock { $0.append(input) }
        return await Self.answer(filing)
    }

    public func suggestWords(_ input: SuggestionInput, title: String, collectionName: String) async -> [String]? {
        recordedWords.withLock { $0.append(WordsCall(input: input, title: title, collectionName: collectionName)) }
        return await Self.answer(words)
    }

    /// Records the call; nothing to warm.
    public func prewarm(collections: [SuggestionCollection]) {
        recordedPrewarms.withLock { $0.append(collections) }
    }

    /// What the model would file the synthetic City Pharmacy receipt as.
    public static func cityPharmacy() -> ScanSuggestion {
        ScanSuggestion(title: "City Pharmacy Receipt", collectionID: "receipts")
    }

    /// The words the model would give the synthetic City Pharmacy receipt.
    public static let cityPharmacyWords = ["receipt", "pharmacy", "purchase"]

    private static func answer<Answer>(_ outcome: Outcome<Answer>) async -> Answer? {
        switch outcome {
        case .arrives(let answer, let delay):
            do {
                try await Task.sleep(for: delay)
                return answer
            } catch {
                return nil  // cancelled during the delay
            }
        case .fails:
            return nil
        case .never:
            // Ends early only when cancelled; either way there is no answer.
            try? await Task.sleep(for: forever)
            return nil
        case .hangsIgnoringCancellation:
            // A task of its own isn't cancelled with the caller, and awaiting its value ignores cancellation.
            await Task { try? await Task.sleep(for: forever) }.value
            return nil
        }
    }
}
