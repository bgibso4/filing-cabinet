import XCTest

/// How long `-SeedScans` / `-SeedTrash` may take to finish. Home shows before seeding ends, and on CI the last seeded
/// scan lands several times later than on a Mac.
let seedingTimeout: TimeInterval = 15

/// Waits until a Home row reads `count`, so every seeded scan it holds has landed. Reading a count as soon as the row
/// exists raced the seeding (CI, run 42479032879). The row reads "Receipts, 3", or "3, Receipts" at accessibility
/// sizes, where the count sits above the name; the first-launch subtitle ("… · 3 mo") matches neither.
@MainActor
func waitForSeeding(of row: XCUIElement, count: Int, file: StaticString = #filePath, line: UInt = #line) {
    let seeded = XCTNSPredicateExpectation(
        predicate: NSPredicate(
            format: "exists == true AND (label ENDSWITH %@ OR label BEGINSWITH %@)", ", \(count)", "\(count), "),
        object: row)
    let result = XCTWaiter.wait(for: [seeded], timeout: seedingTimeout)
    XCTAssertEqual(result, .completed, "\(row) never showed its \(count) seeded scans", file: file, line: line)
}
