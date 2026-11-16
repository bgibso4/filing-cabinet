import Core
import Foundation
import ScreenModels

/// What the phone keeps.
extension AppEnvironment {
    /// The phone's preferences, or for UI tests a suite emptied at each launch, so no run reads or leaves real ones.
    static func preferencesDefaults(isUITest: Bool) -> UserDefaults {
        guard isUITest else { return .standard }
        let suite = "com.cadre.filingcabinet.UITest"
        guard let defaults = UserDefaults(suiteName: suite) else {
            logger.fault("The UI-test preferences suite could not be made")
            fatalError("Filing Cabinet cannot keep UI-test preferences apart")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// What is kept in the phone's defaults: the settings and Search's history. UI tests start past the welcome unless
    /// `-ShowWelcome` asks to see it (M1).
    static func makeKept(options: LaunchOptions) -> (AppPreferences, SearchHistory) {
        let defaults = preferencesDefaults(isUITest: options.isUITest)
        let preferences = AppPreferences(defaults: defaults)
        if options.isUITest {
            preferences.welcomeDone = !options.showWelcome
            if options.ratingDue {
                preferences.savesCount = 9
                preferences.saveDays = [20_270_101, 20_270_102, 20_270_103]
            }
        }
        return (preferences, SearchHistory(defaults: defaults))
    }
}
