import Core
import Foundation
import Library
import Observation

/// Keeps the pending cleanup notes in step with the library (M9): while `run()` runs, every change to the scans,
/// the lifespans, the day or the Notifications switch plans the notes again and replaces the pending ones. With
/// notes off or not allowed by iOS, nothing stays pending. The app runs one from launch.
@Observable
public final class CleanupNotifier {
    /// Bumped by `reschedule()`: a change the notifier can't observe.
    private var nudges = 0

    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let today: Today
    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let center: any CleanupNotifying
    @ObservationIgnored private let clock: AppClock

    public init(
        library: any ScanLibrary,
        today: Today,
        preferences: AppPreferences,
        center: any CleanupNotifying,
        clock: AppClock
    ) {
        self.library = library
        self.today = today
        self.preferences = preferences
        self.center = center
        self.clock = clock
    }

    /// Plans now and after every change, one pass at a time, until cancelled.
    public func run() async {
        let changes = Observations {
            // Read for their changes only: each pass plans from the library and the clock as they are then.
            _ = (self.library.scans, self.library.lifespans, self.today.day, self.preferences.notificationsOn)
            return self.nudges
        }
        for await _ in changes {
            await replacePending()
        }
    }

    /// Plans again for what can't be observed: iOS's answer (changed in iPhone Settings) and the time zone, which
    /// moves the day each scan enters Trash. The app calls it when it comes back.
    public func reschedule() {
        nudges += 1
    }

    private func replacePending() async {
        let authorization = await center.authorization()
        guard preferences.notesReach(given: authorization) else {
            await center.replacePending(with: [])
            return
        }
        // `today` from the same clock as the calendar, so the two can't disagree (Task 13 review).
        let notices = CleanupNotices.plan(
            scans: library.scans, lifespans: library.lifespans, today: clock.today, clock: clock)
        ScreenModelsLog.logger.info("Scheduled \(notices.count, privacy: .public) cleanup notes")
        await center.replacePending(with: notices)
    }
}
