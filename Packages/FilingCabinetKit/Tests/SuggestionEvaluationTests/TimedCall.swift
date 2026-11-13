/// One model call in the eval, cancelled at a limit so a hung model call can't stall a run (Task 4b saw one hang for
/// more than 10 minutes).
struct TimedCall<Answer: Sendable> {
    /// The answer, or nil on any failure or a timeout.
    let answer: Answer?
    /// The whole call, not the reading.
    let milliseconds: Double
    /// The limit passed before an answer, so the call was cancelled.
    let timedOut: Bool

    private enum Outcome: Sendable {
        case answered(Answer?)
        case timedOut
    }

    /// Races `call` against `limit`; the loser is cancelled. Relies on the call returning promptly on cancellation
    /// (`ScanSuggester` promises nil on cancellation), since a task group waits for both children.
    static func run(limit: Duration, _ call: @escaping @Sendable () async -> Answer?) async -> Self {
        let start = ContinuousClock.now
        let outcome = await withTaskGroup(of: Outcome.self) { group in
            group.addTask { .answered(await call()) }
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
        case .answered(let answer): Self(answer: answer, milliseconds: milliseconds, timedOut: false)
        case .timedOut: Self(answer: nil, milliseconds: milliseconds, timedOut: true)
        }
    }
}
