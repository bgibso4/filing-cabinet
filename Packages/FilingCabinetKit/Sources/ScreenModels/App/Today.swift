import Core
import Foundation
import Observation

/// The calendar day the app treats as today. Models read `day`, so they update when it moves; the app calls
/// `refresh()` when the scene becomes active and when the system reports a new day (M5).
@MainActor
@Observable
public final class Today {
    package private(set) var day: CalendarDay

    @ObservationIgnored private let clock: AppClock

    /// The calendar `day` is counted in.
    package var calendar: Calendar { clock.calendar }

    public init(clock: AppClock) {
        self.clock = clock
        day = clock.today
    }

    public func refresh() {
        let current = clock.today
        // Only a real change notifies observers.
        if current != day { day = current }
    }
}
