import Foundation
import Testing

/// Folding Ben's judgements into the cases, on canned cases.
struct JudgementMergeTests {
    private static func item(_ id: String = "a", titles: [String] = ["Alpha"], collection: String = "receipts")
        -> EvaluationCase
    {
        EvaluationCase(
            id: id,
            files: ["\(id).jpg"],
            collection: collection,
            titles: titles,
            searches: ["x"],
            quality: "clean",
            collections: nil
        )
    }

    private static func judgement(
        _ verdict: Verdict, _ title: String, id: String = "a", better: String? = nil, collection: String? = nil
    ) -> Judgement {
        Judgement(id: id, variant: "whole", title: title, verdict: verdict, better: better, collection: collection)
    }

    @Test func yesAddsTheTitle() {
        let merged = JudgementMerge.merged([Self.item()], with: [Self.judgement(.right, "Beta")])

        #expect(merged[0].titles == ["Alpha", "Beta"])
    }

    @Test func betterComesFirst() {
        let merged = JudgementMerge.merged([Self.item()], with: [Self.judgement(.wrong, "Gamma", better: "Best")])

        #expect(merged[0].titles == ["Best", "Alpha"])
    }

    @Test func noRemovesTheTitle() {
        let merged = JudgementMerge.merged(
            [Self.item(titles: ["Alpha", "Beta"])], with: [Self.judgement(.wrong, "alpha")])

        #expect(merged[0].titles == ["Beta"])
    }

    @Test func duplicatesAfterFoldingAreDropped() {
        let merged = JudgementMerge.merged(
            [Self.item(titles: ["Driver's License"])],
            with: [Self.judgement(.right, "drivers  license", better: "Drivers License")])

        #expect(merged[0].titles == ["Drivers License"])
    }

    @Test func collectionIsReplaced() {
        let merged = JudgementMerge.merged([Self.item()], with: [Self.judgement(.right, "Alpha", collection: "notes")])

        #expect(merged[0].collection == "notes")
    }

    @Test func anEmptyTitleCarriesAnswersAndRemovesNothing() {
        let merged = JudgementMerge.merged(
            [Self.item(titles: [""])], with: [Self.judgement(.wrong, "", better: " Mine ", collection: "")])

        #expect(merged[0].titles == ["Mine"])
        #expect(merged[0].collection == "receipts")
    }

    @Test func unjudgedCasesAreUnchanged() {
        let cases = [Self.item("a"), Self.item("b")]
        let merged = JudgementMerge.merged(cases, with: [Self.judgement(.right, "Beta", id: "a")])

        #expect(merged[1].titles == ["Alpha"] && merged[1].collection == "receipts")
        #expect(merged[0].titles == ["Alpha", "Beta"])
    }

    @Test func theCasesFileSurvivesAWriteByteForByte() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "merge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            // Best-effort cleanup of a temp folder.
            try? FileManager.default.removeItem(at: folder)
        }
        let original = try Data(contentsOf: EvaluationCase.fixtures.appending(path: "cases.json"))
        try original.write(to: folder.appending(path: "cases.json"))

        try JudgementMerge.apply([], toCasesIn: folder)

        #expect(try Data(contentsOf: folder.appending(path: "cases.json")) == original)
    }

    @Test func anUnjudgedPrivateCaseKeepsItsShape() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "merge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            // Best-effort cleanup of a temp folder.
            try? FileManager.default.removeItem(at: folder)
        }
        try Data(#"[{"id":"p","files":["p.jpg"]}]"#.utf8).write(to: folder.appending(path: "cases.json"))

        try JudgementMerge.apply([], toCasesIn: folder)

        let text = try String(contentsOf: folder.appending(path: "cases.json"), encoding: .utf8)
        #expect(!text.contains("titles") && !text.contains("\"collection\""))
    }
}
