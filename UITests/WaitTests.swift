import XCTest

/// The waits every journey uses (`Support/Wait.swift`), without the app: the conditions here never read the screen.
@MainActor
final class WaitTests: XCTestCase {
    /// A slow CI runner takes seconds over one read of the screen. A check that started in time counts even when it
    /// ends after the deadline (#104): here the second check starts at about 0.6 s of 1 s and ends at about 1.1 s.
    func testACheckThatStartedBeforeTheDeadlineCounts() {
        let start = Date.now
        let held = XCUIApplication().satisfies(within: 1) { _ in
            Thread.sleep(forTimeInterval: 0.5)
            return Date.now.timeIntervalSince(start) > 0.6
        }
        XCTAssertTrue(held)
    }

    func testAConditionThatNeverHoldsStillTimesOut() {
        let start = Date.now
        XCTAssertFalse(XCUIApplication().satisfies(within: 0.5) { _ in false })
        XCTAssertLessThan(Date.now.timeIntervalSince(start), 2)
    }
}
