import XCTest

extension XCUIElement {
    /// True once `format` holds for this element, within `timeout` seconds of the call (see `holds`).
    func satisfies(_ format: String, _ arguments: Any..., within timeout: TimeInterval) -> Bool {
        holds(NSPredicate(format: format, argumentArray: arguments), for: self, within: timeout)
    }

    /// `waitForExistence`, without its idle first second.
    func appears(within timeout: TimeInterval) -> Bool {
        satisfies("exists == true", within: timeout)
    }

    /// `waitForNonExistence`, without its idle first second.
    func disappears(within timeout: TimeInterval) -> Bool {
        satisfies("exists == false", within: timeout)
    }
}

extension XCUIElementQuery {
    /// True once `format` holds for this query (for example `count == 3`), within `timeout` seconds of the call.
    func satisfies(_ format: String, _ arguments: Any..., within timeout: TimeInterval) -> Bool {
        holds(NSPredicate(format: format, argumentArray: arguments), for: self, within: timeout)
    }
}

/// True once `predicate` holds for `object`, within `timeout` seconds of the call.
///
/// XCTest's own waits (`waitForExistence`, `XCTNSPredicateExpectation`) first check about 1 s after they start,
/// even when the element is already there, and a check still running at the deadline counts as a timeout. One
/// read of the screen can take 4 s on CI, so a 5 s wait could fail on an element that was there all along. This
/// reads once right away, then leaves what is left of the same deadline to XCTest's wait: never more time than
/// `timeout`, and no idle second when the element is ready.
private func holds(_ predicate: NSPredicate, for object: Any, within timeout: TimeInterval) -> Bool {
    let deadline = Date.now.addingTimeInterval(timeout)
    if predicate.evaluate(with: object) { return true }
    let remaining = deadline.timeIntervalSinceNow
    guard remaining > 0 else { return false }
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
    return XCTWaiter.wait(for: [expectation], timeout: remaining) == .completed
}
