import Core
import Foundation
import Observation

/// The settings kept on this phone, in `UserDefaults`.
@MainActor
@Observable
public final class AppPreferences {
    /// The person's wish for cleanup notes. Whether iOS allows them is separate (`SettingsModel`).
    package var notificationsOn: Bool {
        didSet { defaults.set(notificationsOn, forKey: Key.notificationsOn) }
    }

    /// The last day whose cleanup Home's banner has already reported (Task 14), so it counts only what is new.
    public var cleanupSeenThrough: CalendarDay? {
        didSet { defaults.set(cleanupSeenThrough?.storageValue, forKey: Key.cleanupSeenThrough) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Whether cleanup notes reach the person: they want them and iOS allows them.
    package func notesReach(given authorization: NotificationAuthorization) -> Bool {
        notificationsOn && authorization == .authorized
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        notificationsOn = defaults.object(forKey: Key.notificationsOn) as? Bool ?? true
        cleanupSeenThrough = (defaults.object(forKey: Key.cleanupSeenThrough) as? Int).flatMap {
            CalendarDay(storageValue: $0)
        }
    }

    private enum Key {
        static let notificationsOn = "notificationsOn"
        static let cleanupSeenThrough = "cleanupSeenThrough"
    }
}
