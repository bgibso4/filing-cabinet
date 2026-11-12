import Understanding

/// What the model answered for every case, in case order, and for the extra probes.
struct EvaluationRun {
    /// One case's answer.
    struct Result {
        let item: EvaluationCase
        /// Every page's text as read, which Search finds alongside the title and the hidden words.
        let pageText: String
        let answer: TimedSuggestion

        /// Nil when the model gave none (any failure or a timeout).
        var suggestion: ScanSuggestion? { answer.suggestion }
        var milliseconds: Double { answer.milliseconds }
    }

    /// A one-off input that checks a limit (a long scan, many collections) rather than accuracy.
    struct Probe {
        let name: String
        /// What was handed in, in plain words.
        let detail: String
        let answer: TimedSuggestion
    }

    /// Whether page 1 went to the model with the text (the default; `IMAGE=0` turns it off).
    let includesImage: Bool
    /// Where the search words came from (`WORDS=1`: a second call).
    let words: ModelScanSuggester.Words
    let results: [Result]
    let probes: [Probe]
    /// `CASES=`: the filter the cases were picked by, or nil for all of them.
    let filter: String?
    /// `SPLIT=1`: each case asked again for title and collection only, to time it against the full call. Empty when
    /// not measured.
    let titleAndCollectionTimes: [TimedSuggestion]
}
