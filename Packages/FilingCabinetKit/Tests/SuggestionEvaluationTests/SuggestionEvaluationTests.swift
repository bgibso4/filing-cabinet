import Core
import CoreGraphics
import Foundation
import FoundationModels
import ImageIO
import Testing

@testable import Understanding

/// The suggestion evaluation: today's text reader, then the on-device model, over every made-up case, written to
/// `build/suggestion-eval.md`. A report, not a gate: it asserts only that the report was written. The model run is
/// slow and needs Apple Intelligence, so it runs only when `FC_EVAL_SUGGESTIONS=1` (`make eval-suggestions`); in
/// Fast and CI it is skipped. `FC_EVAL_IMAGE=1` (`IMAGE=1`) sends page 1's image too.
@Suite(.timeLimit(.minutes(30)))
struct SuggestionEvaluationTests {
    private static let environment = ProcessInfo.processInfo.environment
    /// The repository root, five levels above this file.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// The one custom collection the made-up cases use.
    private static let taxes = SuggestionCollection(
        id: "taxes", name: "Taxes", about: "Tax forms and records: W-2, 1099, returns, donation receipts")

    @Test(.enabled(if: environment["FC_EVAL_SUGGESTIONS"] == "1", "runs only in make eval-suggestions"))
    func writesTheReport() async throws {
        let includesImage = Self.environment["FC_EVAL_IMAGE"] == "1"
        let suggester = ModelScanSuggester(includesImage: includesImage)
        let outcome: EvaluationReport.Outcome
        if suggester.availability == .available {
            outcome = .ran(try await Self.run(suggester, includesImage: includesImage))
        } else {
            outcome = .unavailable(reason: String(describing: SystemLanguageModel.default.availability))
        }

        let output = Self.root.appending(path: "build/suggestion-eval.md")
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try EvaluationReport(outcome: outcome).markdown.write(to: output, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    /// Every case in order, then the probes. A failed answer is a "no suggestion" row, never a failed test.
    private static func run(_ suggester: ModelScanSuggester, includesImage: Bool) async throws -> EvaluationRun {
        let reader = ScanReader(reader: ReaderKind.text.makeReader())
        var results: [EvaluationRun.Result] = []
        var inputs: [SuggestionInput] = []
        for item in try EvaluationCase.loadAll() {
            let images = try item.files.map(loadImage)
            var texts: [String] = []
            for image in images {
                texts.append(await reader.read([image]).searchText)
            }
            let input = SuggestionInput(
                pageTexts: texts, firstPage: images.first, collections: collections(for: item.collections))
            let (suggestion, milliseconds) = await timed(suggester, input)
            inputs.append(input)
            results.append(EvaluationRun.Result(item: item, suggestion: suggestion, milliseconds: milliseconds))
        }
        var probes = [await longScan(suggester, from: inputs)]
        if let index = results.firstIndex(where: { $0.item.collections != nil }) {
            probes.append(await manyCollections(suggester, case: results[index].item, input: inputs[index]))
        }
        return EvaluationRun(includesImage: includesImage, results: results, probes: probes)
    }

    /// Review Focus 4: a 12-page scan, the 12 longest pages read put together, stays inside the context.
    private static func longScan(_ suggester: ModelScanSuggester, from inputs: [SuggestionInput]) async
        -> EvaluationRun.Probe
    {
        let pages = Array(inputs.flatMap(\.pageTexts).sorted { $0.count > $1.count }.prefix(12))
        let input = SuggestionInput(
            pageTexts: pages, firstPage: inputs.first?.firstPage, collections: SuggestionCollection.builtIns)
        let (suggestion, milliseconds) = await timed(suggester, input)
        return EvaluationRun.Probe(
            name: "12-page scan",
            detail: "the \(pages.count) longest pages, \(pages.reduce(0) { $0 + $1.count }) characters, the built-ins",
            suggestion: suggestion,
            milliseconds: milliseconds
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
        let (suggestion, milliseconds) = await timed(
            suggester,
            SuggestionInput(pageTexts: input.pageTexts, firstPage: input.firstPage, collections: collections))
        return EvaluationRun.Probe(
            name: "\(collections.count) collections",
            detail: "\(item.id) (expected \(item.collection)) with \(extra.count) more made-up collections",
            suggestion: suggestion,
            milliseconds: milliseconds
        )
    }

    /// The built-ins, or the case's own list (built-ins plus taxes).
    private static func collections(for ids: [String]?) -> [SuggestionCollection] {
        guard let ids else { return SuggestionCollection.builtIns }
        let known = SuggestionCollection.builtIns + [taxes]
        return ids.compactMap { id in known.first { $0.id == id } }
    }

    /// The answer and how long the model call took, in milliseconds.
    private static func timed(_ suggester: ModelScanSuggester, _ input: SuggestionInput) async
        -> (ScanSuggestion?, Double)
    {
        let start = ContinuousClock.now
        let suggestion = await suggester.suggest(input)
        let elapsed = ContinuousClock.now - start
        return (suggestion, Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15)
    }

    private static func loadImage(_ file: String) throws -> CGImage {
        let url = EvaluationCase.fixtures.appending(path: "scans/\(file)")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "can't open \(file)")
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil), "can't decode \(file)")
    }
}
