import Testing

@testable import Understanding

/// The report's scoring on canned results; no model runs here.
struct EvaluationReportTests {
    private static func item(
        _ id: String,
        collection: String = "receipts",
        titles: [String] = ["City Pharmacy"],
        searches: [String] = ["medicine", "drugstore"],
        quality: String = "clean"
    ) -> EvaluationCase {
        EvaluationCase(
            id: id,
            files: ["\(id).jpg"],
            collection: collection,
            titles: titles,
            searches: searches,
            quality: quality,
            collections: nil
        )
    }

    private static func result(
        _ item: EvaluationCase,
        collection: String?,
        title: String? = "City Pharmacy",
        words: [String] = [],
        text: String = "",
        milliseconds: Double = 100
    ) -> EvaluationRun.Result {
        EvaluationRun.Result(
            item: item,
            pageText: text,
            answer: TimedSuggestion(
                suggestion: ScanSuggestion(title: title, collectionID: collection, searchWords: words),
                milliseconds: milliseconds,
                timedOut: false
            )
        )
    }

    private static func noSuggestion(_ item: EvaluationCase, milliseconds: Double = 5, timedOut: Bool = false)
        -> EvaluationRun.Result
    {
        EvaluationRun.Result(
            item: item,
            pageText: "",
            answer: TimedSuggestion(suggestion: nil, milliseconds: milliseconds, timedOut: timedOut)
        )
    }

    private static func report(_ results: [EvaluationRun.Result]) -> EvaluationReport {
        EvaluationReport(
            outcome: .ran(EvaluationRun(includesImage: false, wordsPass: false, results: results, probes: [])))
    }

    @Test func collectionAccuracyPerCollection() {
        let report = Self.report([
            Self.result(Self.item("a"), collection: "receipts"),
            Self.result(Self.item("b"), collection: "documents"),
            Self.result(Self.item("c", collection: "wallet"), collection: "wallet"),
            Self.noSuggestion(Self.item("d", collection: "wallet")),
        ])

        #expect(report.collectionAccuracy(in: "receipts") == EvaluationReport.Tally(hits: 1, total: 2))
        #expect(report.collectionAccuracy(in: "wallet") == EvaluationReport.Tally(hits: 1, total: 2))
        #expect(report.markdown.contains("| receipts | 1/2 (50%) |"))
        #expect(report.markdown.contains("| d | wallet | (no suggestion) |"))
    }

    @Test func searchRecallCountsPrefixMatches() {
        let item = Self.item("a", searches: ["lic", "Medicíne", "travel", "card"])

        let missed = item.missedSearches(in: ["driver license", "MEDICINE", "id card"])

        #expect(missed == ["travel"])
        #expect(item.missedSearches(in: ["licorice-free"]) == ["Medicíne", "travel", "card"])
        #expect(EvaluationCase.matches("ense", words: ["license"]) == false)
    }

    @Test func titleCountsAsRightWhenInTitles() {
        let item = Self.item("a", titles: ["City Pharmacy", "Pharmacy Receipt"])

        #expect(item.isRightTitle("  city   PHARMACY "))
        #expect(item.isRightTitle("Pharmacy receipt"))
        #expect(!item.isRightTitle("City Pharmacy Receipt"))
        #expect(!item.isRightTitle(nil))
    }

    @Test func titleIsAcceptableWhenOneContainsTheOther() {
        let item = Self.item("a", titles: ["Driver's License", "Sampleland Passport", "2026 W-2"])

        #expect(item.isAcceptableTitle("Drivers license · Sample State"))
        #expect(item.isAcceptableTitle("Sampleland passport · 2026"))
        #expect(item.isAcceptableTitle("2026 W2 · Northwind"))
        #expect(!item.isAcceptableTitle("Pass"))
        #expect(!item.isAcceptableTitle("Library card"))
        #expect(!item.isAcceptableTitle(nil))
    }

    @Test func bareOneWordTitleIsAcceptableOnlyWhenExact() {
        let item = Self.item("a", titles: ["City Pharmacy receipt", "Passport"])

        #expect(!item.isAcceptableTitle("Receipt"))
        #expect(!item.isAcceptableTitle("pharmacy"))
        #expect(item.isAcceptableTitle("passport"))
        #expect(item.isAcceptableTitle("Pharmacy receipt"))
    }

    @Test func emptyQueryNeverMatches() {
        #expect(!EvaluationCase.matches("", words: ["receipt"]))
        #expect(!EvaluationCase.matches("  ", words: ["receipt"]))
        #expect(!EvaluationCase.isFound("", title: "Receipt", text: "receipt", words: ["receipt"]))
        #expect(!EvaluationCase.isFound(" \n", title: "Receipt", text: "receipt", words: []))
    }

    @Test func searchFindsTermsInTitleTextOrWords() {
        let title = "City Pharmacy receipt"
        let text = "CITY PHARMACY\nIbuprofen 200 mg\nTOTAL 12.40"

        // Substrings of the title or text, folded, like Plan 4's Search.
        #expect(EvaluationCase.isFound("harmac", title: title, text: "", words: []))
        #expect(EvaluationCase.isFound("ibuprofén", title: "", text: text, words: []))
        // Words by M7's part prefix only: "rug" doesn't find "drugstore".
        #expect(EvaluationCase.isFound("drug", title: "", text: "", words: ["drugstore"]))
        #expect(!EvaluationCase.isFound("rug", title: "", text: "", words: ["drugstore"]))
        // Each term may be found by a different source.
        #expect(EvaluationCase.isFound("pharmacy medicine", title: title, text: text, words: ["medicine"]))
        #expect(!EvaluationCase.isFound("pharmacy vet", title: title, text: text, words: ["medicine"]))
    }

    @Test func summaryShowsFoundBySearchAndWordsOnly() {
        let markdown = Self.report([
            Self.result(
                Self.item("a", searches: ["pharmacy", "medicine", "drugstore"]),
                collection: "receipts",
                title: "City Pharmacy",
                words: ["medicine"]
            )
        ]).markdown

        #expect(markdown.contains("| Found by search | 2/3 (67%) |"))
        #expect(markdown.contains("| Search recall, hidden words only | 1/3 (33%) |"))
        #expect(markdown.contains("| a | tune | drugstore | medicine |"))
    }

    @Test func timedOutCallsAreCountedApart() {
        let markdown = Self.report([
            Self.result(Self.item("a"), collection: "receipts"),
            Self.noSuggestion(Self.item("b"), milliseconds: 30_000, timedOut: true),
        ]).markdown

        #expect(markdown.contains("| No suggestion | 1 of 2 (1 timed out) |"))
        #expect(markdown.contains("| b | receipts | (no suggestion, timed out) |"))
    }

    @Test func headerSaysTheAboutTextsKnewTheCategories() {
        #expect(Self.report([]).markdown.contains("written knowing the test set's categories"))
    }

    @Test func multiWordSearchNeedsEveryTerm() {
        #expect(EvaluationCase.matches("gas station", words: ["gas", "station"]))
        #expect(EvaluationCase.matches("Gas Sta", words: ["petrol station", "gas"]))
        #expect(!EvaluationCase.matches("gas station", words: ["gas", "fuel"]))
    }

    @Test func summaryShowsAcceptableAndExactTitles() {
        let item = Self.item("a", titles: ["City Pharmacy"])
        let markdown = Self.report([
            Self.result(item, collection: "receipts", title: "City Pharmacy"),
            Self.result(item, collection: "receipts", title: "City Pharmacy receipt"),
        ]).markdown

        #expect(markdown.contains("| Titles, acceptable | 2/2 (100%) |"))
        #expect(markdown.contains("| Titles, exact | 1/2 (50%) |"))
    }

    @Test func tuneIsEvenIndexesAndHoldoutOdd() {
        let markdown = Self.report([
            Self.result(Self.item("a"), collection: "receipts"),
            Self.result(Self.item("b"), collection: "documents"),
            Self.result(Self.item("c"), collection: "receipts"),
        ]).markdown

        #expect(markdown.contains("| Measure | All | Tune | Holdout |"))
        #expect(markdown.contains("| Collection, all scans | 2/3 (67%) | 2/2 (100%) | 0/1 (0%) |"))
    }

    @Test func timesCountAnsweredCallsOnly() {
        let markdown = Self.report([
            Self.result(Self.item("a"), collection: "receipts", milliseconds: 100),
            Self.result(Self.item("b"), collection: "receipts", milliseconds: 300),
            Self.noSuggestion(Self.item("c"), milliseconds: 9_000),
        ]).markdown

        #expect(markdown.contains("| No suggestion | 1 of 3 (0 timed out) |"))
        #expect(markdown.contains("p50 (answered) | 100 ms |"))
        #expect(markdown.contains("p95 (answered) | 300 ms |"))
    }

    @Test func lowQualityShownSeparately() {
        let report = Self.report([
            Self.result(Self.item("a"), collection: "receipts"),
            Self.result(Self.item("b", quality: "low"), collection: "notes"),
            Self.result(Self.item("c", quality: "low"), collection: "receipts"),
        ])

        #expect(report.collectionAccuracy(quality: "clean") == EvaluationReport.Tally(hits: 1, total: 1))
        #expect(report.collectionAccuracy(quality: "low") == EvaluationReport.Tally(hits: 1, total: 2))
        #expect(report.markdown.contains("| Collection, clean scans | 1/1 (100%) |"))
        #expect(report.markdown.contains("| Collection, low-quality scans | 1/2 (50%) |"))
    }

    @Test func timingP50AndP95() {
        let values = (1...20).map(Double.init)

        #expect(EvaluationReport.percentile(0.5, of: values.shuffled()) == 10)
        #expect(EvaluationReport.percentile(0.95, of: values) == 19)
        #expect(EvaluationReport.percentile(0.5, of: []) == nil)
    }

    @Test func titleMissesAndMissedSearchesAreListed() {
        let markdown = Self.report([
            Self.result(
                Self.item("a", searches: ["medicine", "drug"]),
                collection: "receipts",
                title: "Library card",
                words: ["drugstore"]
            )
        ]).markdown

        #expect(markdown.contains("| a | tune | City Pharmacy | Library card |"))
        #expect(markdown.contains("| a | tune | medicine | drugstore |"))
        #expect(markdown.contains("| Search recall, hidden words only | 1/2 (50%) |"))
    }

    @Test func unavailableModelIsOneLineAndNoNumbers() {
        let markdown = EvaluationReport(outcome: .unavailable(reason: "appleIntelligenceNotEnabled")).markdown

        #expect(markdown.contains("The on-device model isn't available on this Mac (appleIntelligenceNotEnabled)"))
        #expect(!markdown.contains("%"))
    }
}
