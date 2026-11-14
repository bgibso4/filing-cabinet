import Foundation

/// Folds Ben's judgements into the cases (`make eval-merge`).
enum JudgementMerge {
    /// A `yes` title and any `better` are added to that case's `titles` (`better` first, no duplicates after folding);
    /// a `no` title is removed if present; a `collection` replaces the case's. Cases without judgements are unchanged.
    static func merged(_ cases: [EvaluationCase], with judgements: [Judgement]) -> [EvaluationCase] {
        cases.map { item in
            let mine = judgements.filter { $0.id == item.id }
            guard !mine.isEmpty else { return item }
            let rejected = mine.filter { $0.verdict == .wrong && !$0.title.isEmpty }.map {
                EvaluationCase.loosened($0.title)
            }
            let kept = item.titles.filter { !rejected.contains(EvaluationCase.loosened($0)) }
            let better = mine.compactMap { $0.better?.trimmingCharacters(in: .whitespacesAndNewlines) }
            let accepted = mine.filter { $0.verdict == .right }.map(\.title)
            var seen = Set<String>()
            let titles = (better + kept + accepted).filter {
                !$0.isEmpty && seen.insert(EvaluationCase.loosened($0)).inserted
            }
            let picked = mine.compactMap(\.collection).last { !$0.isEmpty }
            return EvaluationCase(
                id: item.id,
                files: item.files,
                collection: picked ?? item.collection,
                titles: titles,
                searches: item.searches,
                quality: item.quality,
                collections: item.collections
            )
        }
    }

    /// Reads `<folder>/cases.json`, merges the judgements for its cases and writes it back.
    static func apply(_ judgements: [Judgement], toCasesIn folder: URL) throws {
        let cases = try EvaluationCase.loadAll(from: folder)
        try EvaluationCase.write(merged(cases, with: judgements), to: folder)
    }
}
