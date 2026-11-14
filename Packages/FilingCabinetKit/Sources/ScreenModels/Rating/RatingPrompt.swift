import Core
import Observation

/// When to ask for a rating: after ten saves on at least three different days, once per app version, only ever right
/// after a save (Plan 6 §6b). The root asks Apple's prompt when `isDue` and nothing else is up, then calls `asked()`.
/// Only `recordSave` can make it due: at launch it is never due, so a cancelled scan after an update doesn't ask.
@MainActor
@Observable
public final class RatingPrompt {
    package private(set) var isDue = false

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let version: String
    @ObservationIgnored private let analytics: any Analytics

    private static let savesNeeded = 10
    private static let daysNeeded = 3

    public init(preferences: AppPreferences, version: String, analytics: any Analytics) {
        self.preferences = preferences
        self.version = version
        self.analytics = analytics
    }

    /// A scan was saved on `day`. Only the three most recent distinct days are kept: three is all the rule needs.
    public func recordSave(on day: CalendarDay) {
        preferences.savesCount += 1
        let value = day.storageValue
        if !preferences.saveDays.contains(value) {
            preferences.saveDays = Array((preferences.saveDays + [value]).suffix(Self.daysNeeded))
        }
        refresh()
    }

    /// The prompt was requested: this version won't ask again.
    package func asked() {
        preferences.ratingAskedVersion = version
        analytics.send(.ratingRequested)
        refresh()
    }

    private func refresh() {
        isDue =
            preferences.savesCount >= Self.savesNeeded
            && Set(preferences.saveDays).count >= Self.daysNeeded
            && preferences.ratingAskedVersion != version
    }
}
