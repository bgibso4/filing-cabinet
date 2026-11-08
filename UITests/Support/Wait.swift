import XCTest

extension XCUIElement {
    /// True once `format` holds for this element, within `timeout` seconds of the call.
    ///
    /// XCTest's own waits (`waitForExistence`, `XCTNSPredicateExpectation`) first check about 1 s after they start,
    /// even when the element is already there, and a check still running at the deadline counts as a timeout. One
    /// read of the screen can take 4 s on CI, so a 5 s wait could fail on an element that was there all along. This
    /// reads once right away, then leaves what is left of the same deadline to XCTest's wait: never more time than
    /// `timeout`, and no idle second when the element is ready.
    func satisfies(_ format: String, _ arguments: Any..., within timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: format, argumentArray: arguments)
        let deadline = Date.now.addingTimeInterval(timeout)
        if predicate.evaluate(with: self) { return true }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return false }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: remaining) == .completed
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
