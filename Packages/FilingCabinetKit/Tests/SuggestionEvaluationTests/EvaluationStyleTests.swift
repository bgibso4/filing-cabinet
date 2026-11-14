import Testing

@testable import Understanding

/// The report with several title styles, and the name and kind match rules; no model runs here.
struct EvaluationStyleTests {
    private static func twoStyles(
        _ item: EvaluationCase, whole: String, parts: TitleParts, composed: String
    ) -> EvaluationRun.Result {
        func call(_ suggestion: ScanSuggestion) -> TimedCall<ScanSuggestion> {
            TimedCall(answer: suggestion, milliseconds: 100, timedOut: false)
        }
        var partsAnswer = ScanSuggestion(title: composed, collectionID: "receipts")
        partsAnswer.titleParts = parts
        return EvaluationRun.Result(
            item: item,
            pageText: "",
            filings: [
                (style: .whole, call: call(ScanSuggestion(title: whole, collectionID: "receipts"))),
                (style: .parts, call: call(partsAnswer)),
            ],
            words: TimedCall(answer: [], milliseconds: 50, timedOut: false)
        )
    }

    @Test func eachStyleGetsItsOwnTitleRowsAndPartsMatchRates() {
        let item = EvaluationReportTests.item("a", titles: ["City Pharmacy Receipt"])
        let markdown = EvaluationReportTests.report([
            Self.twoStyles(
                item,
                whole: "City Pharmacy",
                parts: TitleParts(name: "City Pharmacy", kind: "Receipt"),
                composed: "City Pharmacy Receipt"
            )
        ]).markdown

        #expect(markdown.contains("| Titles, right (whole) | 0/1 (0%) |"))
        #expect(markdown.contains("| Titles, right (parts) | 1/1 (100%) |"))
        #expect(markdown.contains("| Name matched (parts, answered) | 1/1 (100%) |"))
        #expect(markdown.contains("| Kind matched (parts, answered) | 1/1 (100%) |"))
        #expect(markdown.contains("| Case | Set | Expected | Got (whole) | Got (parts) |"))
    }

    @Test func oneStyleKeepsThePlainRowLabels() {
        let markdown = EvaluationReportTests.report([
            EvaluationReportTests.result(EvaluationReportTests.item("a"), collection: "receipts")
        ]).markdown

        #expect(markdown.contains("| Titles, right | 1/1 (100%) |"))
        #expect(!markdown.contains("Name matched"))
    }

    @Test func nameAndKindMatchOnWordBoundaries() {
        let item = EvaluationReportTests.item("a", titles: ["City Pharmacy Receipt"])

        #expect(item.nameMatches(TitleParts(name: "city pharmacy", kind: "")))
        #expect(!item.nameMatches(TitleParts(name: "City Pharm", kind: "")))
        #expect(!item.nameMatches(TitleParts(name: "", kind: "Receipt")))
        #expect(item.kindMatches(TitleParts(name: "", kind: "RECEIPT")))
        #expect(!item.kindMatches(TitleParts(name: "", kind: "")))
        #expect(!item.kindMatches(TitleParts(name: "", kind: "Pharmacy")))
        #expect(
            EvaluationReportTests.item("b", titles: ["Library Card"]).nameMatches(
                TitleParts(name: "", kind: "Library Card")))
    }
}
