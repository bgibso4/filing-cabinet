import Foundation
import Testing

/// Defaults no other test sees. They are emptied when made and on `cleanUp()`, so no file stays behind.
struct FreshDefaults {
    let suite = "ScreenModelsTests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}
