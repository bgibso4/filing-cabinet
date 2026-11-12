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
        milliseconds: Double = 100
    ) -> EvaluationRun.Result {
        EvaluationRun.Result(
            item: item,
            suggestion: ScanSuggestion(title: title, collectionID: collection, searchWords: words),
            milliseconds: milliseconds
        )
    }

    private static func report(_ results: [EvaluationRun.Result]) -> EvaluationReport {
        EvaluationReport(outcome: .ran(EvaluationRun(includesImage: false, results: results, probes: [])))
    }

    @Test func collectionAccuracyPerCollection() {
        let report = Self.report([
            Self.result(Self.item("a"), collection: "receipts"),
            Self.result(Self.item("b"), collection: "documents"),
            Self.result(Self.item("c", collection: "wallet"), collection: "wallet"),
            EvaluationRun.Result(item: Self.item("d", collection: "wallet"), suggestion: nil, milliseconds: 5),
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
        #expect(item.isAcceptableTitle("Passport"))
        #expect(item.isAcceptableTitle("2026 W2 · Northwind"))
        #expect(!item.isAcceptableTitle("Pass"))
        #expect(!item.isAcceptableTitle("Library card"))
        #expect(!item.isAcceptableTitle(nil))
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
            EvaluationRun.Result(item: Self.item("c"), suggestion: nil, milliseconds: 9_000),
        ]).markdown

        #expect(markdown.contains("| No suggestion | 1 of 3 |"))
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
        #expect(markdown.contains("| Search recall | 1/2 (50%) |"))
    }

    @Test func unavailableModelIsOneLineAndNoNumbers() {
        let markdown = EvaluationReport(outcome: .unavailable(reason: "appleIntelligenceNotEnabled")).markdown

        #expect(markdown.contains("The on-device model isn't available on this Mac (appleIntelligenceNotEnabled)"))
        #expect(!markdown.contains("%"))
    }
}
