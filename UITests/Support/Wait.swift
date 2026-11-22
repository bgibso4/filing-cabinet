import XCTest

extension XCUIElement {
    /// True once `format` holds for this element, within `timeout` seconds of the call (see `holds`).
    func satisfies(_ format: String, _ arguments: Any..., within timeout: TimeInterval) -> Bool {
        holds(NSPredicate(format: format, argumentArray: arguments), for: self, within: timeout)
    }

    /// True once `condition` holds for this element, within `timeout` seconds of the call (see `holds`).
    func satisfies(within timeout: TimeInterval, _ condition: @escaping @Sendable (XCUIElement) -> Bool) -> Bool {
        holds(NSPredicate { object, _ in (object as? XCUIElement).map(condition) ?? false }, for: self, within: timeout)
    }

    /// `waitForExistence`, without its idle first second.
    func appears(within timeout: TimeInterval) -> Bool {
        satisfies("exists == true", within: timeout)
    }

    /// `waitForNonExistence`, without its idle first second.
    func disappears(within timeout: TimeInterval) -> Bool {
        satisfies("exists == false", within: timeout)
    }

    /// True once two reads of this element's frame in a row agree, within `timeout` seconds: whatever moved or scaled
    /// it has stopped. For an element whose resting frame isn't known ahead, such as a system prompt's button.
    func holdsStill(within timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        var last = frame
        while Date.now < deadline {
            let next = frame
            if next == last { return true }
            last = next
        }
        return false
    }
}

extension XCUIElementQuery {
    /// True once `format` holds for this query (for example `count == 3`), within `timeout` seconds of the call.
    func satisfies(_ format: String, _ arguments: Any..., within timeout: TimeInterval) -> Bool {
        holds(NSPredicate(format: format, argumentArray: arguments), for: self, within: timeout)
    }
}

/// How long a wait rests between two checks: XCTest's own waits check about once a second, and the journeys were
/// written against that. At 0.1 s a wait returned in the middle of a transition and the next step ran into it: a hit
/// test while the camera slid away, an audit while the review card faded in.
private let checkPause: TimeInterval = 1

/// True once `predicate` holds for `object`, in a check that started within `timeout` seconds of the call.
///
/// XCTest's own waits (`waitForExistence`, `XCTNSPredicateExpectation`) first check about 1 s after they start,
/// even when the element is already there, and a check still running at the deadline counts as a timeout, whatever
/// it read. One read of the screen takes 1.4 to 7 s on a slow CI runner, so a wait could fail on a screen that was
/// right in time (run 44756089080: a check with 2.8 s left took 3.3 s). This checks right away and then again and
/// again; the deadline decides whether another check starts, not whether a started one counts. A wait can so run
/// over `timeout` by one check.
private func holds(_ predicate: NSPredicate, for object: Any, within timeout: TimeInterval) -> Bool {
    let deadline = Date.now.addingTimeInterval(timeout)
    repeat {
        if predicate.evaluate(with: object) { return true }
        RunLoop.current.run(until: Date.now.addingTimeInterval(checkPause))
    } while Date.now < deadline
    return false
}
