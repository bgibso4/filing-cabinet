import Understanding

/// What the model answered for every case, in case order, and for the extra probes.
struct EvaluationRun {
    /// One case's answers: the filing call, then the words call, as the app makes them (review, then Save).
    struct Result {
        let item: EvaluationCase
        /// Every page's text as read, which Search finds alongside the title and the hidden words.
        let pageText: String
        /// The filing call once per title style, in the order the styles were asked for (the first is the primary).
        let filings: [(style: TitleStyle, call: TimedCall<ScanSuggestion>)]
        let words: TimedCall<[String]>
        /// From the private set (`PRIVATE=`), not the made-up one: counted in its own column, never in Tune or Holdout.
        var isPrivate = false

        /// The primary style's filing call: the one the words call and the case rows follow.
        var filing: TimedCall<ScanSuggestion> { filings[0].call }

        /// Nil when the model gave none (any failure or a timeout).
        var suggestion: ScanSuggestion? { filing.answer }

        /// What `style`'s filing call gave; nil when it gave none or the style wasn't run.
        func suggestion(for style: TitleStyle) -> ScanSuggestion? {
            filings.first { $0.style == style }?.call.answer
        }
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
    /// The title styles compared, in the order asked for (`VARIANT=`).
    var styles: [TitleStyle] { results.first?.filings.map(\.style) ?? [.whole] }
    let probes: [Probe]
    /// `CASES=`: the filter the cases were picked by, or nil for all of them.
    let filter: String?
}

extension EvaluationRun.Result {
    /// One filing call, in the primary style (`.whole`).
    init(
        item: EvaluationCase,
        pageText: String,
        filing: TimedCall<ScanSuggestion>,
        words: TimedCall<[String]>,
        isPrivate: Bool = false
    ) {
        self.init(
            item: item,
            pageText: pageText,
            filings: [(style: .whole, call: filing)],
            words: words,
            isPrivate: isPrivate
        )
    }
}
