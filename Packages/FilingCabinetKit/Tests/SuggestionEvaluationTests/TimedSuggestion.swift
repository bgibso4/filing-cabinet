import Understanding

/// One `suggest` call in the eval, cancelled at a limit so a hung model call can't stall a run (Task 4b saw one hang
/// for more than 10 minutes).
struct TimedSuggestion {
    /// The answer, or nil on any failure or a timeout.
    let suggestion: ScanSuggestion?
    /// The whole `suggest` call (both model calls with `WORDS=1`), not the reading.
    let milliseconds: Double
    /// The limit passed before an answer, so the call was cancelled.
    let timedOut: Bool

    private enum Outcome: Sendable {
        case answered(ScanSuggestion?)
        case timedOut
    }

    /// Races the call against `limit`; the loser is cancelled. Relies on the suggester returning promptly on
    /// cancellation (`ScanSuggester` promises nil on cancellation), since a task group waits for both children.
    static func suggest(_ suggester: any ScanSuggester, _ input: SuggestionInput, limit: Duration) async -> Self {
        let start = ContinuousClock.now
        let outcome = await withTaskGroup(of: Outcome.self) { group in
            group.addTask { .answered(await suggester.suggest(input)) }
            group.addTask {
                // Cancelled only when the call answered first, and then this outcome is never read.
                try? await Task.sleep(for: limit)
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
        let elapsed = ContinuousClock.now - start
        let milliseconds = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        return switch outcome {
        case .answered(let suggestion): Self(suggestion: suggestion, milliseconds: milliseconds, timedOut: false)
        case .timedOut: Self(suggestion: nil, milliseconds: milliseconds, timedOut: true)
        }
    }
}
