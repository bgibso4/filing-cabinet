import Foundation
import Synchronization

/// A clock the test moves by hand: pass `{ now.now }` to an `AppClock`, then `set` a later date.
package final class MovableNow: Sendable {
    private let date: Mutex<Date>

    package init(_ date: Date) {
        self.date = Mutex(date)
    }

    package var now: Date { date.withLock { $0 } }

    package func set(_ newDate: Date) {
        date.withLock { $0 = newDate }
    }
}
