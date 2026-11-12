import Synchronization
import Understanding

/// Test double: answers every `suggest` with one scripted outcome.
public final class FakeScanSuggester: ScanSuggester {
    package enum Outcome: Sendable {
        /// Return this suggestion after `after`; nil if cancelled first.
        case arrives(ScanSuggestion, after: Duration)
        /// Wait until cancelled, then return nil.
        case never
        /// Report unavailable and return nil at once.
        case unavailable
    }

    /// Long enough that only a cancel ends `.never` in any test.
    private static let forever = Duration.seconds(86_400)

    private let outcome: Outcome
    private let recorded = Mutex<[SuggestionInput]>([])

    package init(_ outcome: Outcome) {
        self.outcome = outcome
    }

    /// Every input `suggest` was called with, in order.
    package var calls: [SuggestionInput] { recorded.withLock { $0 } }

    public var availability: SuggesterAvailability {
        if case .unavailable = outcome { .unavailable } else { .available }
    }

    public func suggest(_ input: SuggestionInput) async -> ScanSuggestion? {
        recorded.withLock { $0.append(input) }
        switch outcome {
        case .arrives(let suggestion, let delay):
            do {
                try await Task.sleep(for: delay)
                return suggestion
            } catch {
                return nil  // cancelled during the delay
            }
        case .never:
            // Ends early only when cancelled; either way there is no suggestion.
            try? await Task.sleep(for: Self.forever)
            return nil
        case .unavailable:
            return nil
        }
    }

    /// What the model would say for the synthetic City Pharmacy receipt.
    package static func cityPharmacy() -> ScanSuggestion {
        ScanSuggestion(
            title: "City Pharmacy receipt", collectionID: "receipts", searchWords: ["receipt", "pharmacy", "purchase"])
    }
}
