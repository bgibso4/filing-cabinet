import Foundation
import Understanding

/// Renders the suggestion evaluation as Markdown: a summary, accuracy per collection, every title not acceptable, every
/// search not found, the probes, then one row per case. Informs; it never decides anything.
struct EvaluationReport {
    enum Outcome {
        case ran(EvaluationRun)
        /// The model can't answer on this Mac; the report says so and has no numbers.
        case unavailable(reason: String)
    }

    /// Right answers out of the answers counted.
    struct Tally: Equatable {
        let hits: Int
        let total: Int

        var text: String {
            total == 0 ? "0/0" : "\(hits)/\(total) (\(Int((Double(hits) / Double(total) * 100).rounded()))%)"
        }
    }

    let outcome: Outcome

    var markdown: String {
        switch outcome {
        case .unavailable(let reason):
            (Self.header + [
                "The on-device model isn't available on this Mac (\(reason)), so this report has no numbers."
            ])
            .joined(separator: "\n") + "\n"
        case .ran(let run):
            (Self.header + Self.about(run) + summary(run) + perCollection(run) + titleMisses(run)
                + unfoundSearches(run) + probes(run) + everyCase(run)).joined(separator: "\n") + "\n"
        }
    }

    private var results: [EvaluationRun.Result] {
        if case .ran(let run) = outcome { run.results } else { [] }
    }

    func collectionAccuracy(in collection: String) -> Tally {
        Self.collections(results.filter { $0.item.collection == collection })
    }

    func collectionAccuracy(quality: String) -> Tally {
        Self.collections(results, quality: quality)
    }

    /// The nearest-rank percentile, or nil with no values.
    static func percentile(_ share: Double, of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        // The small nudge keeps 0.95 × 20 at rank 19 despite floating point.
        let rank = Int((share * Double(values.count) - 1e-9).rounded(.up))
        return values.sorted()[min(max(rank, 1), values.count) - 1]
    }

    private static func collections(_ results: [EvaluationRun.Result]) -> Tally {
        Tally(hits: results.count { $0.suggestion?.collectionID == $0.item.collection }, total: results.count)
    }

    private static func collections(_ results: [EvaluationRun.Result], quality: String) -> Tally {
        collections(results.filter { $0.item.quality == quality })
    }

    private static func titles(_ results: [EvaluationRun.Result]) -> Tally {
        Tally(hits: results.count { $0.item.isRightTitle($0.suggestion?.title) }, total: results.count)
    }

    private static func acceptableTitles(_ results: [EvaluationRun.Result]) -> Tally {
        Tally(hits: results.count { $0.item.isAcceptableTitle($0.suggestion?.title) }, total: results.count)
    }

    /// The headline: searches Search finds from the suggested title, the page text and the hidden words.
    private static func foundBySearch(_ results: [EvaluationRun.Result]) -> Tally {
        searches(results, missed: unfound)
    }

    /// Searches the hidden words alone find.
    private static func wordsOnly(_ results: [EvaluationRun.Result]) -> Tally {
        searches(results) { $0.item.missedSearches(in: $0.suggestion?.searchWords ?? []) }
    }

    private static func searches(
        _ results: [EvaluationRun.Result], missed: (EvaluationRun.Result) -> [String]
    ) -> Tally {
        let total = results.reduce(0) { $0 + $1.item.searches.count }
        return Tally(hits: total - results.reduce(0) { $0 + missed($1).count }, total: total)
    }

    private static func unfound(_ result: EvaluationRun.Result) -> [String] {
        result.item.unfoundSearches(
            title: result.suggestion?.title, text: result.pageText, words: result.suggestion?.searchWords ?? [])
    }

    // MARK: - Sections

    private static let header = [
        "# Suggestion evaluation",
        "",
        "Written by `make eval-suggestions` (SuggestionEvaluationTests) from the made-up test set in "
            + "`Tests/SuggestionEvaluationTests/Fixtures/`. A report, not a gate. The built-in collections' `about` "
            + "texts were written knowing the test set's categories, so collection accuracy may read high.",
        "",
    ]

    private static func about(_ run: EvaluationRun) -> [String] {
        [
            "\(run.results.count) cases, read with today's text reader, then the on-device model "
                + (run.includesImage ? "with page 1's image (`IMAGE=1`)" : "on the text alone (no image)")
                + (run.wordsPass ? ", then a second call for search words (`WORDS=1`)." : ", one call.")
                + " Times are the whole suggestion (every model call, not the reading), on this Mac: relative only."
                + " A call still running after 30 s is cancelled and counts as no suggestion.",
            "",
        ]
    }

    /// The headline measures for every case, then for the tune set (even indexes in cases.json, the cases a prompt
    /// is tuned on) and the holdout (odd indexes, read only to check). Times are over the calls that answered.
    private func summary(_ run: EvaluationRun) -> [String] {
        let sets = [run.results, Self.split(run.results, even: true), Self.split(run.results, even: false)]
        func row(_ measure: String, _ tally: ([EvaluationRun.Result]) -> Tally) -> String {
            "| \(measure) | " + sets.map { tally($0).text }.joined(separator: " | ") + " |"
        }
        let times = run.results.filter { $0.suggestion != nil }.map(\.milliseconds)
        let none = run.results.count { $0.suggestion == nil }
        let timedOut = run.results.count { $0.answer.timedOut }
        return [
            "## Summary", "", "| Measure | All | Tune | Holdout |", "|---|---|---|---|",
            row("Collection, all scans", Self.collections),
            row("Collection, clean scans") { Self.collections($0, quality: "clean") },
            row("Collection, low-quality scans") { Self.collections($0, quality: "low") },
            row("Titles, acceptable", Self.acceptableTitles),
            row("Titles, exact", Self.titles),
            row("Found by search", Self.foundBySearch),
            row("Search recall, hidden words only", Self.wordsOnly),
            "",
            "| Measure | Result |", "|---|---|",
            "| No suggestion | \(none) of \(run.results.count) (\(timedOut) timed out) |",
            "| Time per scan, p50 (answered) | \(Self.milliseconds(Self.percentile(0.5, of: times))) |",
            "| Time per scan, p95 (answered) | \(Self.milliseconds(Self.percentile(0.95, of: times))) |",
            "",
        ]
    }

    /// The results at even (tune) or odd (holdout) indexes.
    private static func split(_ results: [EvaluationRun.Result], even: Bool) -> [EvaluationRun.Result] {
        results.enumerated().filter { $0.offset.isMultiple(of: 2) == even }.map(\.element)
    }

    private func perCollection(_ run: EvaluationRun) -> [String] {
        var seen: Set<String> = []
        let order = run.results.map(\.item.collection).filter { seen.insert($0).inserted }
        return ["## Collection by collection", "", "| Collection | Right |", "|---|---|"]
            + order.map { "| \($0) | \(collectionAccuracy(in: $0).text) |" } + [""]
    }

    private func titleMisses(_ run: EvaluationRun) -> [String] {
        let misses = run.results.enumerated().filter {
            !$0.element.item.isAcceptableTitle($0.element.suggestion?.title)
        }
        return [
            "## Titles not acceptable (\(misses.count))", "", "| Case | Set | Expected | Got |", "|---|---|---|---|",
        ]
            + misses.map { index, result in
                "| \(result.item.id) | \(Self.set(index)) | \(Self.cell(result.item.titles.joined(separator: " / "))) | "
                    + "\(Self.cell(Self.title(result.suggestion))) |"
            } + [""]
    }

    private func unfoundSearches(_ run: EvaluationRun) -> [String] {
        let rows = run.results.enumerated().compactMap { index, result -> String? in
            let missed = Self.unfound(result)
            guard !missed.isEmpty else { return nil }
            return "| \(result.item.id) | \(Self.set(index)) | \(Self.cell(missed.joined(separator: ", "))) | "
                + "\(Self.cell(Self.words(result.suggestion))) |"
        }
        return [
            "## Searches not found (\(rows.count) cases)", "", "| Case | Set | Not found | Words returned |",
            "|---|---|---|---|",
        ] + rows + [""]
    }

    private func probes(_ run: EvaluationRun) -> [String] {
        ["## Probes", "", "| Probe | Handed in | Collection | Title | Time |", "|---|---|---|---|---|"]
            + run.probes.map { probe in
                "| \(probe.name) | \(Self.cell(probe.detail)) | \(Self.collection(probe.answer)) | "
                    + "\(Self.cell(probe.answer.suggestion?.title ?? "")) | \(Self.milliseconds(probe.answer.milliseconds)) |"
            } + [""]
    }

    private func everyCase(_ run: EvaluationRun) -> [String] {
        ["## Every case", "", "| Case | Expected | Got | Title | Words | Time |", "|---|---|---|---|---|---|"]
            + run.results.map { result in
                "| \(result.item.id) | \(result.item.collection) | \(Self.collection(result.answer)) | "
                    + "\(Self.cell(result.suggestion?.title ?? "")) | "
                    + "\(Self.cell(result.suggestion?.searchWords.joined(separator: ", ") ?? "")) | "
                    + "\(Self.milliseconds(result.milliseconds)) |"
            }
    }

    // MARK: - Cells

    private static func collection(_ answer: TimedSuggestion) -> String {
        guard let suggestion = answer.suggestion else {
            return answer.timedOut ? "(no suggestion, timed out)" : "(no suggestion)"
        }
        return suggestion.collectionID ?? "(none)"
    }

    private static func title(_ suggestion: ScanSuggestion?) -> String {
        guard let suggestion else { return "(no suggestion)" }
        return suggestion.title ?? "(none)"
    }

    private static func words(_ suggestion: ScanSuggestion?) -> String {
        guard let suggestion else { return "(no suggestion)" }
        return suggestion.searchWords.isEmpty ? "(none)" : suggestion.searchWords.joined(separator: ", ")
    }

    /// "tune" for an even index in cases.json, "holdout" for an odd one.
    private static func set(_ index: Int) -> String {
        index.isMultiple(of: 2) ? "tune" : "holdout"
    }

    /// Keeps a value inside one table cell.
    private static func cell(_ text: String) -> String {
        text.replacing("|", with: "\\|").replacing("\n", with: " ")
    }

    private static func milliseconds(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded())) ms" } ?? "n/a"
    }
}
