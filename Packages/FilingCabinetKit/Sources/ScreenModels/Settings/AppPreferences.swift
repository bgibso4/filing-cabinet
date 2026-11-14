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

    /// The person's wish for Apple Intelligence: names and files new scans and gives scans search words. Whether the
    /// model can answer is separate (`ScanSuggester.availability`).
    public var appleIntelligenceOn: Bool {
        didSet { defaults.set(appleIntelligenceOn, forKey: Key.appleIntelligenceOn) }
    }

    /// The last day whose cleanup Home's banner has already reported (Task 14), so it counts only what is new.
    public var cleanupSeenThrough: CalendarDay? {
        didSet { defaults.set(cleanupSeenThrough?.storageValue, forKey: Key.cleanupSeenThrough) }
    }

    /// Light, dark or the phone's own; the app applies it at its root.
    package var appearance: AppearanceChoice {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// The first-launch welcome has been completed on this install; until then it shows at every launch (Plan 6 §4).
    public var welcomeDone: Bool {
        didSet { defaults.set(welcomeDone, forKey: Key.welcomeDone) }
    }

    /// Scans saved on this install, for the rating prompt (Plan 6 §6b).
    public var savesCount: Int {
        didSet { defaults.set(savesCount, forKey: Key.savesCount) }
    }

    /// The three most recent distinct days a scan was saved (`CalendarDay.storageValue`), oldest first.
    public var saveDays: [Int] {
        didSet { defaults.set(saveDays, forKey: Key.saveDays) }
    }

    /// The app version the rating prompt was last requested in.
    package var ratingAskedVersion: String? {
        didSet { defaults.set(ratingAskedVersion, forKey: Key.ratingAskedVersion) }
    }

    /// The `SpotlightSync.version` the Spotlight index was last built with; 0 before the first.
    package var spotlightVersion: Int {
        didSet { defaults.set(spotlightVersion, forKey: Key.spotlightVersion) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Whether cleanup notes reach the person: they want them and iOS allows them.
    package func notesReach(given authorization: NotificationAuthorization) -> Bool {
        notificationsOn && authorization == .authorized
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        notificationsOn = defaults.object(forKey: Key.notificationsOn) as? Bool ?? true
        appleIntelligenceOn = defaults.object(forKey: Key.appleIntelligenceOn) as? Bool ?? true
        welcomeDone = defaults.bool(forKey: Key.welcomeDone)
        savesCount = defaults.integer(forKey: Key.savesCount)
        saveDays = defaults.array(forKey: Key.saveDays) as? [Int] ?? []
        ratingAskedVersion = defaults.string(forKey: Key.ratingAskedVersion)
        spotlightVersion = defaults.integer(forKey: Key.spotlightVersion)
        appearance = AppearanceChoice(stored: defaults.string(forKey: Key.appearance))
        cleanupSeenThrough = (defaults.object(forKey: Key.cleanupSeenThrough) as? Int).flatMap {
            CalendarDay(storageValue: $0)
        }
    }

    private enum Key {
        static let notificationsOn = "notificationsOn"
        static let appearance = "appearance"
        static let appleIntelligenceOn = "appleIntelligenceOn"
        static let cleanupSeenThrough = "cleanupSeenThrough"
        static let welcomeDone = "welcomeDone"
        static let savesCount = "savesCount"
        static let saveDays = "saveDays"
        static let ratingAskedVersion = "ratingAskedVersion"
        static let spotlightVersion = "spotlightVersion"
    }
}
