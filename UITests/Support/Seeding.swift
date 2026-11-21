import XCTest

/// How long `-SeedScans` / `-SeedTrash` may take to finish. Home shows before seeding ends, and on CI the last seeded
/// scan lands several times later than on a Mac.
let seedingTimeout: TimeInterval = 15

/// Waits until a Home row reads `count`, so every seeded scan it holds has landed. Reading a count as soon as the row
/// exists raced the seeding (CI, run 42479032879). The row reads "Receipts, 3", or "3, Receipts" at accessibility
/// sizes, where the count sits above the name; the first-launch subtitle ("… · 3 mo") matches neither.
///
/// Each check reads the screen once. As a predicate on `exists` and `label` it read three times, at three different
/// moments, and one read took 1.4 to 7 s on a slow CI runner: the first check ran for 12 s of the 15 and its two
/// label reads straddled the last scan landing, so the wait gave up 6 s after the row read 3 (run 44756089080).
@MainActor
func waitForSeeding(of row: XCUIElement, count: Int, file: StaticString = #filePath, line: UInt = #line) {
    let seeded = row.satisfies(within: seedingTimeout) { row in
        // try?: `snapshot()` throws while the row isn't on screen yet, which is "not seeded yet".
        // assumeIsolated: XCTest checks a wait's condition on the main thread, where the test itself runs.
        guard let label = MainActor.assumeIsolated({ try? row.snapshot().label }) else { return false }
        return label.hasSuffix(", \(count)") || label.hasPrefix("\(count), ")
    }
    XCTAssertTrue(seeded, "\(row) never showed its \(count) seeded scans", file: file, line: line)
}
