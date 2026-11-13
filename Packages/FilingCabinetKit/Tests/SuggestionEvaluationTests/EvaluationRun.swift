import Understanding

/// What the model answered for every case, in case order, and for the extra probes.
struct EvaluationRun {
    /// One case's answers: the filing call, then the words call, as the app makes them (review, then Save).
    struct Result {
        let item: EvaluationCase
        /// Every page's text as read, which Search finds alongside the title and the hidden words.
        let pageText: String
        let filing: TimedCall<ScanSuggestion>
        let words: TimedCall<[String]>

        /// Nil when the model gave none (any failure or a timeout).
        var suggestion: ScanSuggestion? { filing.answer }
        /// The hidden words; empty when the words call gave none.
        var searchWords: [String] { words.answer ?? [] }
    }

    /// A one-off input that checks a limit (a long scan, many collections) rather than accuracy: a filing call.
    struct Probe {
        let name: String
        /// What was handed in, in plain words.
        let detail: String
        let filing: TimedCall<ScanSuggestion>
    }

    /// Whether page 1 went to the filing call with the text (the default; `IMAGE=0` turns it off).
    let includesImage: Bool
    let results: [Result]
    let probes: [Probe]
    /// `CASES=`: the filter the cases were picked by, or nil for all of them.
    let filter: String?
}
