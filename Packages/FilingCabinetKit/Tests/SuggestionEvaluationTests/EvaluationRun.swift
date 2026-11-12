import Understanding

/// What the model answered for every case, in case order, and for the extra probes.
struct EvaluationRun {
    /// One case's answer; `suggestion` is nil when the model gave none (any failure).
    struct Result {
        let item: EvaluationCase
        let suggestion: ScanSuggestion?
        /// The `suggest` call alone, not the reading.
        let milliseconds: Double
    }

    /// A one-off input that checks a limit (a long scan, many collections) rather than accuracy.
    struct Probe {
        let name: String
        /// What was handed in, in plain words.
        let detail: String
        let suggestion: ScanSuggestion?
        let milliseconds: Double
    }

    /// Whether page 1 went to the model with the text (`IMAGE=1`).
    let includesImage: Bool
    let results: [Result]
    let probes: [Probe]
}
