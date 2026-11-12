import Core
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import Understanding

/// The suggestion evaluation: today's text reader, then the on-device model, over every made-up case, written to
/// `build/suggestion-eval.md`. A report, not a gate: it asserts only that the report was written. The model run is
/// slow and needs Apple Intelligence, so it runs only when `FC_EVAL_SUGGESTIONS=1` (`make eval-suggestions`); in
/// Fast and CI it is skipped. Page 1's image goes in unless `FC_EVAL_IMAGE=0` (`IMAGE=0`); `FC_EVAL_WORDS=1`
/// (`WORDS=1`) adds the second call for search words; `FC_EVAL_SPLIT=1` (`SPLIT=1`) also times a call for title and
/// collection only; `FC_EVAL_CASES` (`CASES=`) runs only some cases and skips the probes.
@Suite(.timeLimit(.minutes(30)))
struct SuggestionEvaluationTests {
    private static let environment = ProcessInfo.processInfo.environment
    /// The repository root, five levels above this file.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// Each `suggest` call is cancelled after this, so one hung model call can't stall the run.
    private static let callLimit = Duration.seconds(30)

    /// The one custom collection the made-up cases use.
    private static let taxes = SuggestionCollection(
        id: "taxes", name: "Taxes", about: "Tax forms and records: W-2, 1099, returns, donation receipts")

    @Test(.enabled(if: environment["FC_EVAL_SUGGESTIONS"] == "1", "runs only in make eval-suggestions"))
    func writesTheReport() async throws {
        let includesImage = Self.environment["FC_EVAL_IMAGE"] != "0"
        let words: ModelScanSuggester.Words = Self.environment["FC_EVAL_WORDS"] == "1" ? .separateCall : .inAnswer
        let suggester = ModelScanSuggester(includesImage: includesImage, words: words)
        let split =
            Self.environment["FC_EVAL_SPLIT"] == "1"
            ? ModelScanSuggester(includesImage: includesImage, words: .skipped) : nil
        let outcome: EvaluationReport.Outcome
        if suggester.availability == .available {
            outcome = .ran(
                try await Self.run(suggester, split: split, includesImage: includesImage, words: words))
        } else {
            // Only ModelScanSuggester imports FoundationModels, so the system's own reason isn't read here.
            outcome = .unavailable(reason: "ModelScanSuggester reports it unavailable")
        }

        let output = Self.root.appending(path: "build/suggestion-eval.md")
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try EvaluationReport(outcome: outcome).markdown.write(to: output, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    /// Every case in order, then the probes. A failed answer is a "no suggestion" row, never a failed test. With
    /// `split`, each case is also asked for title and collection only, first on odd cases and second on even ones, so
    /// neither call always runs on a model the other just woke.
    private static func run(
        _ suggester: ModelScanSuggester,
        split: ModelScanSuggester?,
        includesImage: Bool,
        words: ModelScanSuggester.Words
    ) async throws -> EvaluationRun {
        let reader = ScanReader(reader: ReaderKind.text.makeReader())
        var results: [EvaluationRun.Result] = []
        var inputs: [SuggestionInput] = []
        var splitTimes: [TimedSuggestion] = []
        let filter = environment["FC_EVAL_CASES"].flatMap { $0.allSatisfy(\.isWhitespace) ? nil : $0 }
        for (index, item) in EvaluationCase.selected(try EvaluationCase.loadAll(), by: filter).enumerated() {
            let images = try item.files.map(loadImage)
            var texts: [String] = []
            for image in images {
                texts.append(await reader.read([image]).searchText)
            }
            let input = SuggestionInput(
                pageTexts: texts, firstPage: images.first, collections: try collections(for: item.collections))
            let splitFirst = !index.isMultiple(of: 2)
            if let split, splitFirst {
                splitTimes.append(await TimedSuggestion.suggest(split, input, limit: callLimit))
            }
            let answer = await TimedSuggestion.suggest(suggester, input, limit: callLimit)
            if let split, !splitFirst {
                splitTimes.append(await TimedSuggestion.suggest(split, input, limit: callLimit))
            }
            inputs.append(input)
            results.append(
                EvaluationRun.Result(item: item, pageText: texts.joined(separator: "\n"), answer: answer))
        }
        var probes: [EvaluationRun.Probe] = []
        if filter == nil { probes.append(await longScan(suggester, from: inputs)) }
        if filter == nil, let index = results.firstIndex(where: { $0.item.collections != nil }) {
            probes.append(await manyCollections(suggester, case: results[index].item, input: inputs[index]))
        }
        return EvaluationRun(
            includesImage: includesImage,
            words: words,
            results: results,
            probes: probes,
            filter: filter,
            titleAndCollectionTimes: splitTimes
        )
    }

    /// Review Focus 4: a 12-page scan, the 12 longest pages read put together, stays inside the context.
    private static func longScan(_ suggester: ModelScanSuggester, from inputs: [SuggestionInput]) async
        -> EvaluationRun.Probe
    {
        let pages = Array(inputs.flatMap(\.pageTexts).sorted { $0.count > $1.count }.prefix(12))
        let input = SuggestionInput(
            pageTexts: pages, firstPage: inputs.first?.firstPage, collections: SuggestionCollection.builtIns)
        return EvaluationRun.Probe(
            name: "12-page scan",
            detail: "the \(pages.count) longest pages, \(pages.reduce(0) { $0 + $1.count }) characters, the built-ins",
            answer: await TimedSuggestion.suggest(suggester, input, limit: callLimit)
        )
    }

    /// The prompt budget with a long collection list: a taxes case with 20 more made-up collections handed in.
    private static func manyCollections(
        _ suggester: ModelScanSuggester,
        case item: EvaluationCase,
        input: SuggestionInput
    ) async -> EvaluationRun.Probe {
        let names = [
            "Car", "Pets", "Garden", "Recipes", "Travel", "Kids school", "Health", "Gym", "Bank", "Warranties",
            "Manuals", "Utilities", "Rent", "Insurance", "Art", "Music", "Work", "Hobbies", "Gifts", "Moving",
        ]
        let extra = names.map { name in
            SuggestionCollection(
                id: name.lowercased().replacing(" ", with: "-"),
                name: name,
                about: "Anything about \(name.lowercased()): letters, forms, receipts and notes"
            )
        }
        let collections = input.collections + extra
        let answer = await TimedSuggestion.suggest(
            suggester,
            SuggestionInput(pageTexts: input.pageTexts, firstPage: input.firstPage, collections: collections),
            limit: callLimit
        )
        return EvaluationRun.Probe(
            name: "\(collections.count) collections",
            detail: "\(item.id) (expected \(item.collection)) with \(extra.count) more made-up collections",
            answer: answer
        )
    }

    /// The built-ins, or the case's own list (built-ins plus taxes); every id must be known.
    private static func collections(for ids: [String]?) throws -> [SuggestionCollection] {
        guard let ids else { return SuggestionCollection.builtIns }
        let known = SuggestionCollection.builtIns + [taxes]
        return try ids.map { id in try #require(known.first { $0.id == id }, "unknown collection \(id)") }
    }

    private static func loadImage(_ file: String) throws -> CGImage {
        let url = EvaluationCase.fixtures.appending(path: "scans/\(file)")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "can't open \(file)")
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil), "can't decode \(file)")
    }
}
