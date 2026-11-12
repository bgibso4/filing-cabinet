import Foundation
import Understanding

/// Renders the suggestion evaluation as Markdown: a summary, accuracy per collection, every title miss, every
/// missed search, the probes, then one row per case. Informs; it never decides anything.
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
                + missedSearches(run) + probes(run) + everyCase(run)).joined(separator: "\n") + "\n"
        }
    }

    private var results: [EvaluationRun.Result] {
        if case .ran(let run) = outcome { run.results } else { [] }
    }

    func collectionAccuracy(in collection: String) -> Tally {
        Self.collections(results.filter { $0.item.collection == collection })
    }

    func collectionAccuracy(quality: String) -> Tally {
        Self.collections(results.filter { $0.item.quality == quality })
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

    private static func titles(_ results: [EvaluationRun.Result]) -> Tally {
        Tally(hits: results.count { $0.item.isRightTitle($0.suggestion?.title) }, total: results.count)
    }

    private static func searches(_ results: [EvaluationRun.Result]) -> Tally {
        let total = results.reduce(0) { $0 + $1.item.searches.count }
        let missed = results.reduce(0) { $0 + $1.item.missedSearches(in: $1.suggestion?.searchWords ?? []).count }
        return Tally(hits: total - missed, total: total)
    }

    // MARK: - Sections

    private static let header = [
        "# Suggestion evaluation",
        "",
        "Written by `make eval-suggestions` (SuggestionEvaluationTests) from the made-up test set in "
            + "`Tests/SuggestionEvaluationTests/Fixtures/`. A report, not a gate.",
        "",
    ]

    private static func about(_ run: EvaluationRun) -> [String] {
        [
            "\(run.results.count) cases, read with today's text reader, then the on-device model "
                + (run.includesImage ? "with page 1's image (`IMAGE=1`)." : "on the text alone (no image).")
                + " Times are the model call alone, on this Mac: relative only.",
            "",
        ]
    }

    private func summary(_ run: EvaluationRun) -> [String] {
        let times = run.results.map(\.milliseconds)
        let none = run.results.count { $0.suggestion == nil }
        return [
            "## Summary", "", "| Measure | Result |", "|---|---|",
            "| Collection, all scans | \(Self.collections(run.results).text) |",
            "| Collection, clean scans | \(collectionAccuracy(quality: "clean").text) |",
            "| Collection, low-quality scans | \(collectionAccuracy(quality: "low").text) |",
            "| Titles | \(Self.titles(run.results).text) |",
            "| Search recall | \(Self.searches(run.results).text) |",
            "| No suggestion | \(none) of \(run.results.count) |",
            "| Time per scan, p50 | \(Self.milliseconds(Self.percentile(0.5, of: times))) |",
            "| Time per scan, p95 | \(Self.milliseconds(Self.percentile(0.95, of: times))) |",
            "",
        ]
    }

    private func perCollection(_ run: EvaluationRun) -> [String] {
        var seen: Set<String> = []
        let order = run.results.map(\.item.collection).filter { seen.insert($0).inserted }
        return ["## Collection by collection", "", "| Collection | Right |", "|---|---|"]
            + order.map { "| \($0) | \(collectionAccuracy(in: $0).text) |" } + [""]
    }

    private func titleMisses(_ run: EvaluationRun) -> [String] {
        let misses = run.results.filter { !$0.item.isRightTitle($0.suggestion?.title) }
        return ["## Title misses (\(misses.count))", "", "| Case | Expected | Got |", "|---|---|---|"]
            + misses.map { result in
                "| \(result.item.id) | \(Self.cell(result.item.titles.joined(separator: " / "))) | "
                    + "\(Self.cell(Self.title(result.suggestion))) |"
            } + [""]
    }

    private func missedSearches(_ run: EvaluationRun) -> [String] {
        let rows = run.results.compactMap { result -> String? in
            let missed = result.item.missedSearches(in: result.suggestion?.searchWords ?? [])
            guard !missed.isEmpty else { return nil }
            return "| \(result.item.id) | \(Self.cell(missed.joined(separator: ", "))) | "
                + "\(Self.cell(Self.words(result.suggestion))) |"
        }
        return ["## Missed searches (\(rows.count) cases)", "", "| Case | Missed | Words returned |", "|---|---|---|"]
            + rows + [""]
    }

    private func probes(_ run: EvaluationRun) -> [String] {
        ["## Probes", "", "| Probe | Handed in | Collection | Title | Time |", "|---|---|---|---|---|"]
            + run.probes.map { probe in
                "| \(probe.name) | \(Self.cell(probe.detail)) | \(Self.collection(probe.suggestion)) | "
                    + "\(Self.cell(probe.suggestion?.title ?? "")) | \(Self.milliseconds(probe.milliseconds)) |"
            } + [""]
    }

    private func everyCase(_ run: EvaluationRun) -> [String] {
        ["## Every case", "", "| Case | Expected | Got | Title | Words | Time |", "|---|---|---|---|---|---|"]
            + run.results.map { result in
                "| \(result.item.id) | \(result.item.collection) | \(Self.collection(result.suggestion)) | "
                    + "\(Self.cell(result.suggestion?.title ?? "")) | "
                    + "\(Self.cell(result.suggestion?.searchWords.joined(separator: ", ") ?? "")) | "
                    + "\(Self.milliseconds(result.milliseconds)) |"
            }
    }

    // MARK: - Cells

    private static func collection(_ suggestion: ScanSuggestion?) -> String {
        guard let suggestion else { return "(no suggestion)" }
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

    /// Keeps a value inside one table cell.
    private static func cell(_ text: String) -> String {
        text.replacing("|", with: "\\|").replacing("\n", with: " ")
    }

    private static func milliseconds(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded())) ms" } ?? "n/a"
    }
}
