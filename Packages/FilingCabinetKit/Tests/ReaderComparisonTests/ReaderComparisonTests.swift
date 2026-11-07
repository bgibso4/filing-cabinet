import Core
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import Understanding

/// The reader bake-off (A12): both readers on every synthetic scan in `design/prototype/scans/`, written to
/// `build/reader-comparison.md`. A report, not a gate: it fails only when a fixture can't be loaded or a reader
/// fails on every page. Run with `make compare-readers`.
@Suite(.timeLimit(.minutes(20)))
struct ReaderComparisonTests {
    /// The repository root, five levels above this file.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test func writeTheReport() async throws {
        let fixtures = try Self.loadFixtures()
        let scans = try fixtures.map { fixture in try fixture.files.map(Self.loadImage) }
        let pageCount = scans.reduce(0) { $0 + $1.count }

        var runs: [ComparisonRun] = []
        for kind in ReaderKind.allCases {
            let run = await Self.run(kind, on: scans)
            #expect(run.failedPages < pageCount, "\(kind.rawValue) failed on every page")
            runs.append(run)
        }
        let visionTitles = await Self.visionTitles(of: scans)

        let report = ComparisonReport(fixtures: fixtures, runs: runs, visionTitles: visionTitles).markdown
        let output = Self.root.appending(path: "build/reader-comparison.md")
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try report.write(to: output, atomically: true, encoding: .utf8)
    }

    /// One reader over every scan. The first read (page 1 of the first scan) is the cold read and the warm-up;
    /// every scan after it is timed warm.
    private static func run(_ kind: ReaderKind, on scans: [[CGImage]]) async -> ComparisonRun {
        let reader = ScanReader(reader: kind.makeReader())
        let cold = await timed { _ = await reader.read([scans[0][0]]) }

        var readings: [ScanReading] = []
        var msPerPage: [Double] = []
        for pages in scans {
            var reading: ScanReading?
            let elapsed = await timed { reading = await reader.read(pages) }
            if let reading { readings.append(reading) }
            msPerPage.append(elapsed / Double(pages.count))
        }
        return ComparisonRun(kind: kind, coldMilliseconds: cold, readings: readings, msPerPage: msPerPage)
    }

    /// Vision's own document title for page 1 of each scan (M23).
    private static func visionTitles(of scans: [[CGImage]]) async -> [String?] {
        let reader = DocumentRecognitionReader()
        var titles: [String?] = []
        for pages in scans {
            titles.append(await reader.documentTitle(pages[0]))
        }
        return titles
    }

    /// Milliseconds the work took.
    private static func timed(_ work: () async -> Void) async -> Double {
        let start = ContinuousClock.now
        await work()
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
    }

    private static func loadFixtures() throws -> [ComparisonFixture] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "expected.json")
        return try JSONDecoder().decode([ComparisonFixture].self, from: Data(contentsOf: url))
    }

    private static func loadImage(_ file: String) throws -> CGImage {
        let url = root.appending(path: "design/prototype/scans/\(file)")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "can't open \(file)")
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil), "can't decode \(file)")
    }
}
