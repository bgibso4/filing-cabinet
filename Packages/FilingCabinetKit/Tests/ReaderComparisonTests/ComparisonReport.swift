import Core
import Foundation
import Understanding

/// Renders the bake-off as Markdown: totals, cold reads, then one row per fixture.
struct ComparisonReport {
    let fixtures: [ComparisonFixture]
    let runs: [ComparisonRun]
    let visionTitles: [String?]

    var markdown: String {
        (header + totals + coldReads + perFixture).joined(separator: "\n") + "\n"
    }

    private var header: [String] {
        [
            "# Reader comparison",
            "",
            "Written by `make compare-readers` (ReaderComparisonTests) from \(fixtures.count) synthetic scans in "
                + "`design/prototype/scans/`. A report, not a gate (A12). Every timing below is from this Mac: "
                + "**relative only**; the iPhone numbers come from `make device-perf`.",
            "",
        ]
    }

    private var totals: [String] {
        var lines = ["## Totals", "", "| Reader | Titles hit | Mean recall |", "|---|---|---|"]
        for run in runs {
            let hits = zip(fixtures, run.readings).count { fixture, reading in fixture.isHit(reading.title) }
            let recalls = zip(fixtures, run.readings).map { fixture, reading in fixture.recall(in: reading.searchText) }
            let mean = recalls.reduce(0, +) / Double(max(recalls.count, 1))
            lines.append("| \(run.kind.rawValue) | \(hits)/\(fixtures.count) | \(Self.percent(mean)) |")
        }
        return lines + [""]
    }

    private var coldReads: [String] {
        var lines = [
            "## Cold first read (relative only)",
            "",
            "Each reader's first read in this process, on page 1 of the first fixture. The readers run in order "
                + "(\(runs.map(\.kind.rawValue).joined(separator: ", "))) in one process, so later readers start "
                + "with Vision already loaded. Warm timings below start after this read.",
            "",
            "| Reader | First read |",
            "|---|---|",
        ]
        for run in runs {
            lines.append("| \(run.kind.rawValue) | \(Self.milliseconds(run.coldMilliseconds)) |")
        }
        return lines + [""]
    }

    private var perFixture: [String] {
        var head = "| File(s) | Expected title |"
        var rule = "|---|---|"
        for run in runs {
            head += " \(run.kind.rawValue) title | \(run.kind.rawValue) recall | \(run.kind.rawValue) warm ms/page |"
            rule += "---|---|---|"
        }
        var lines = [
            "## Per fixture (warm ms per page: relative only)", "", head + " Vision document title |", rule + "---|",
        ]
        for (index, fixture) in fixtures.enumerated() {
            var row = "| \(Self.cell(fixture.files.joined(separator: ", "))) | \(Self.cell(fixture.title)) |"
            for run in runs {
                let reading = run.readings[index]
                let mark = fixture.isHit(reading.title) ? "✓" : "✗"
                row += " \(mark) \(Self.cell(reading.title ?? "(none)")) |"
                row += " \(Self.percent(fixture.recall(in: reading.searchText))) |"
                row += " \(Self.milliseconds(run.msPerPage[index])) |"
            }
            row += " \(Self.cell(visionTitles[index] ?? "(none)")) |"
            lines.append(row)
        }
        return lines
    }

    /// Keeps a value inside one table cell.
    private static func cell(_ text: String) -> String {
        text.replacing("|", with: "\\|").replacing("\n", with: " ")
    }

    private static func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }

    private static func milliseconds(_ value: Double) -> String {
        "\(Int(value.rounded())) ms"
    }
}
