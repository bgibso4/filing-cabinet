import Core
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import Understanding

/// The suggestion evaluation: today's text reader, then the on-device model, over every made-up case, written to
/// `build/suggestion-eval.md`. A report, not a gate: it asserts only that the report was written. The model run is
/// slow and needs Apple Intelligence, so it runs only when `FC_EVAL_SUGGESTIONS=1` (`make eval-suggestions`); in
/// Fast and CI it is skipped. Each case gets the app's two calls: title and collection, then search words. Page 1's
/// image goes to the first unless `FC_EVAL_IMAGE=0` (`IMAGE=0`); `FC_EVAL_CASES` (`CASES=`) runs only some cases and
/// skips the probes. `FC_EVAL_PRIVATE` (`PRIVATE=`) is a folder outside the repo (`cases.json` and `scans/`) whose cases
/// run after the made-up ones; the report is then written there, not to `build/`, with `review.html` beside it.
/// `FC_EVAL_JUDGED` (`make eval-merge JUDGED=`) merges the answers downloaded from that page into the cases files.
@Suite(.timeLimit(.minutes(30)))
struct SuggestionEvaluationTests {
    private static let environment = ProcessInfo.processInfo.environment
    /// The repository root, five levels above this file.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// `PRIVATE=`: the private set's folder, with a leading `~` expanded; nil when not set.
    private static let privateFolder: URL? = environment["FC_EVAL_PRIVATE"].flatMap {
        $0.allSatisfy(\.isWhitespace)
            ? nil : URL(filePath: ($0 as NSString).expandingTildeInPath, directoryHint: .isDirectory)
    }

    /// `VARIANT=`: the title styles compared, a comma list of `TitleStyle` names in the order given; `parts` when not
    /// set. An unknown name fails the run rather than being skipped.
    private static func titleStyles() throws -> [TitleStyle] {
        guard let list = environment["FC_EVAL_VARIANT"], !list.allSatisfy(\.isWhitespace) else { return [.parts] }
        return try list.split(separator: ",").map { name in
            let name = name.trimmingCharacters(in: .whitespaces)
            return try #require(TitleStyle(rawValue: name), "unknown VARIANT \(name): use whole, parts")
        }
    }

    /// Each model call is cancelled after this, so one hung model call can't stall the run.
    private static let callLimit = Duration.seconds(30)

    /// The one custom collection the made-up cases use.
    private static let taxes = SuggestionCollection(
        id: "taxes", name: "Taxes", about: "Tax forms and records: W-2, 1099, returns, donation receipts")

    @Test(.enabled(if: environment["FC_EVAL_SUGGESTIONS"] == "1", "runs only in make eval-suggestions"))
    func writesTheReport() async throws {
        let includesImage = Self.environment["FC_EVAL_IMAGE"] != "0"
        let styles = try Self.titleStyles()
        let suggesters = styles.map { ($0, ModelScanSuggester(includesImage: includesImage, titleStyle: $0)) }
        let outcome: EvaluationReport.Outcome
        if suggesters[0].1.availability == .available {
            outcome = .ran(try await Self.run(suggesters, includesImage: includesImage))
        } else {
            // Only ModelScanSuggester imports FoundationModels, so the system's own reason isn't read here.
            outcome = .unavailable(reason: "ModelScanSuggester reports it unavailable")
        }

        let folder = Self.privateFolder ?? Self.root.appending(path: "build")
        let output = folder.appending(path: "suggestion-eval.md")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try EvaluationReport(outcome: outcome).markdown.write(to: output, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: output.path))
        if case .ran(let run) = outcome {
            let page = ReviewPage.html(for: try run.results.map { try Self.reviewEntry(for: $0) })
            try page.write(to: folder.appending(path: "review.html"), atomically: true, encoding: .utf8)
        }
    }

    /// `make eval-merge`: the made-up cases take Ben's answers for their ids into the source tree's `cases.json`, the
    /// private ones into `<PRIVATE>/cases.json`; each file only the answers for its own cases.
    @Test(.enabled(if: environment["FC_EVAL_JUDGED"].map { !$0.isEmpty } ?? false, "runs only in make eval-merge"))
    func mergesJudgements() throws {
        let path = try #require(Self.environment["FC_EVAL_JUDGED"])
        let judgements = try JSONDecoder().decode(
            [Judgement].self, from: Data(contentsOf: URL(filePath: (path as NSString).expandingTildeInPath)))
        let madeUp = Self.root.appending(path: "Packages/FilingCabinetKit/Tests/SuggestionEvaluationTests/Fixtures")
        for folder in [madeUp] + [Self.privateFolder].compactMap({ $0 }) {
            let ids = Set(try EvaluationCase.loadAll(from: folder).map(\.id))
            try JudgementMerge.apply(judgements.filter { ids.contains($0.id) }, toCasesIn: folder)
        }
    }

    /// Page 1 as a JPEG (any size the scan came in, at most 1200 px wide or tall), with the model's title and collection.
    private static func reviewEntry(for result: EvaluationRun.Result) throws -> ReviewPage.Entry {
        let scans = (result.isPrivate ? privateFolder ?? EvaluationCase.fixtures : EvaluationCase.fixtures)
            .appending(path: "scans")
        let file = try #require(result.item.files.first)
        let source = try #require(CGImageSourceCreateWithURL(scans.appending(path: file) as CFURL, nil))
        let options =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1200,
            ] as CFDictionary
        let image = try #require(CGImageSourceCreateThumbnailAtIndex(source, 0, options))
        let data = NSMutableData()
        let jpeg = try #require(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(jpeg, image, nil)
        #expect(CGImageDestinationFinalize(jpeg))
        return ReviewPage.Entry(
            item: result.item,
            isPrivate: result.isPrivate,
            image: data as Data,
            collectionID: result.suggestion?.collectionID,
            titles: result.filings.map { (style: $0.style.rawValue, title: $0.call.answer?.title) }
        )
    }

    /// Every case in order, then the probes. A failed answer is a "no suggestion" row, never a failed test.
    /// `suggesters` holds one per title style, the first the primary: its title goes to the words call.
    private static func run(_ suggesters: [(TitleStyle, ModelScanSuggester)], includesImage: Bool) async throws
        -> EvaluationRun
    {
        let suggester = suggesters[0].1
        let reader = ScanReader(reader: ReaderKind.text.makeReader())
        var results: [EvaluationRun.Result] = []
        var inputs: [SuggestionInput] = []
        let filter = environment["FC_EVAL_CASES"].flatMap { $0.allSatisfy(\.isWhitespace) ? nil : $0 }
        var cases = EvaluationCase.selected(try EvaluationCase.loadAll(), by: filter).map { ($0, false) }
        if let folder = privateFolder {
            cases += EvaluationCase.selected(try EvaluationCase.loadAll(from: folder), by: filter).map { ($0, true) }
        }
        for (item, isPrivate) in cases {
            let scans = (isPrivate ? privateFolder ?? EvaluationCase.fixtures : EvaluationCase.fixtures)
                .appending(path: "scans")
            let images = try item.files.map { try loadImage($0, in: scans) }
            var texts: [String] = []
            for image in images {
                texts.append(await reader.read([image]).searchText)
            }
            let input = SuggestionInput(
                pageTexts: texts, firstPage: images.first, collections: try collections(for: item.collections))
            var filings: [(style: TitleStyle, call: TimedCall<ScanSuggestion>)] = []
            for (style, suggester) in suggesters {
                filings.append((style, await TimedCall.run(limit: callLimit) { await suggester.suggestFiling(input) }))
            }
            let filing = filings[0].call
            // As saved: the suggestion where it gave one, else what the person would have chosen.
            let title = filing.answer?.title ?? item.titles.first ?? ""
            let collectionID = filing.answer?.collectionID ?? item.collection
            let collectionName = input.collections.first { $0.id == collectionID }?.name ?? collectionID
            let words = await TimedCall.run(limit: callLimit) {
                await suggester.suggestWords(input, title: title, collectionName: collectionName)
            }
            inputs.append(input)
            results.append(
                EvaluationRun.Result(
                    item: item,
                    pageText: texts.joined(separator: "\n"),
                    filings: filings,
                    words: words,
                    isPrivate: isPrivate
                ))
        }
        var probes: [EvaluationRun.Probe] = []
        if filter == nil { probes.append(await longScan(suggester, from: inputs)) }
        if filter == nil, let index = results.firstIndex(where: { $0.item.collections != nil }) {
            probes.append(await manyCollections(suggester, case: results[index].item, input: inputs[index]))
        }
        return EvaluationRun(includesImage: includesImage, results: results, probes: probes, filter: filter)
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
            filing: await TimedCall.run(limit: callLimit) { await suggester.suggestFiling(input) }
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
        let wide = SuggestionInput(pageTexts: input.pageTexts, firstPage: input.firstPage, collections: collections)
        let filing = await TimedCall.run(limit: callLimit) { await suggester.suggestFiling(wide) }
        return EvaluationRun.Probe(
            name: "\(collections.count) collections",
            detail: "\(item.id) (expected \(item.collection)) with \(extra.count) more made-up collections",
            filing: filing
        )
    }

    /// The built-ins, or the case's own list (built-ins plus taxes); every id must be known.
    private static func collections(for ids: [String]?) throws -> [SuggestionCollection] {
        guard let ids else { return SuggestionCollection.builtIns }
        let known = SuggestionCollection.builtIns + [taxes]
        return try ids.map { id in try #require(known.first { $0.id == id }, "unknown collection \(id)") }
    }

    private static func loadImage(_ file: String, in scans: URL) throws -> CGImage {
        let url = scans.appending(path: file)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "can't open \(file)")
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil), "can't decode \(file)")
    }
}
