import Testing

@testable import Understanding

/// How the report treats the private set (`PRIVATE=`), on canned results.
struct EvaluationPrivateReportTests {
    private typealias Base = EvaluationReportTests

    @Test func privateCasesHaveTheirOwnColumn() {
        let markdown = Base.report([
            Base.result(Base.item("a"), collection: "receipts"),
            Base.result(Base.item("b"), collection: "receipts"),
            Base.result(Base.item("p"), collection: "documents", isPrivate: true),
        ]).markdown

        #expect(markdown.contains("| Measure | All | Tune | Holdout | Private |"))
        #expect(markdown.contains("| Collection, all scans | 2/2 (100%) | 1/1 (100%) | 1/1 (100%) | 0/1 (0%) |"))
    }

    @Test func allColumnIgnoresPrivateCases() {
        let markdown = Base.report([
            Base.result(Base.item("a"), collection: "receipts"),
            Base.result(Base.item("p"), collection: "notes", isPrivate: true),
        ]).markdown

        #expect(markdown.contains("| Collection, all scans | 1/1 (100%) | 1/1 (100%) | 0/0 | 0/1 (0%) |"))
    }

    @Test func unjudgedPrivateCasesCountNowhere() {
        let unjudged = Base.item("u", collection: "", titles: [], searches: [])
        let markdown = Base.report([
            Base.result(Base.item("a"), collection: "receipts"),
            Base.result(unjudged, collection: "receipts", isPrivate: true),
        ]).markdown

        #expect(markdown.contains("| Collection, all scans | 1/1 (100%) | 1/1 (100%) | 0/0 | 0/0 |"))
        #expect(markdown.contains("| u | unjudged |"))
        #expect(!markdown.contains("| u | tune |"))
    }

    @Test func tuneAndHoldoutIgnorePrivateCases() {
        let markdown = Base.report([
            Base.result(Base.item("a"), collection: "receipts"),
            Base.result(Base.item("p"), collection: "notes", isPrivate: true),
            Base.result(Base.item("b"), collection: "receipts"),
        ]).markdown

        #expect(markdown.contains("| Collection, all scans | 2/2 (100%) | 1/1 (100%) | 1/1 (100%) | 0/1 (0%) |"))
    }

    @Test func privateMissesAreListedByIdOnly() {
        let markdown = Base.report([
            Base.result(Base.item("p", titles: ["Secret"]), collection: "receipts", title: "Other", isPrivate: true)
        ]).markdown

        #expect(markdown.contains("### Private (1)\n\np\n"))
        #expect(!markdown.contains("| p | tune"))
        #expect(!markdown.contains("| p | holdout"))
    }
}
