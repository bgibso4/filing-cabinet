import Understanding

extension EvaluationReport {
    /// The measures a title style changes: collection (with several styles), titles right, found by search, and for
    /// `.parts` how often its name and kind matched. One style keeps the plain labels.
    func styleRows(
        _ run: EvaluationRun, row: (String, ([EvaluationRun.Result]) -> Tally) -> String
    ) -> [String] {
        let several = run.styles.count > 1
        var rows: [String] = []
        for style in run.styles {
            let label = several ? " (\(style.rawValue))" : ""
            let only: TitleStyle? = several ? style : nil
            if several { rows.append(row("Collection, all scans\(label)") { Self.collections($0, style: style) }) }
            rows.append(row("Titles, right\(label)") { Self.titles($0, style: only) })
            rows.append(row("Found by search\(label)") { Self.foundBySearch($0, style: only) })
        }
        if run.styles.contains(.parts) {
            rows.append(row("Name matched (parts, answered)") { Self.partsMatches($0).name })
            rows.append(row("Kind matched (parts, answered)") { Self.partsMatches($0).kind })
        }
        return rows
    }

    /// Of the `.parts` answers, how many names (the expected title starts with it) and kinds (it ends with it) matched.
    static func partsMatches(_ results: [EvaluationRun.Result]) -> (name: Tally, kind: Tally) {
        let answered = results.compactMap { result in result.suggestion(for: .parts)?.titleParts.map { (result, $0) } }
        return (
            name: Tally(hits: answered.count { $0.0.item.nameMatches($0.1) }, total: answered.count),
            kind: Tally(hits: answered.count { $0.0.item.kindMatches($0.1) }, total: answered.count)
        )
    }

}
