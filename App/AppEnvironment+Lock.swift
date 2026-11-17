import Core
import ScreenModels

#if DEBUG
    import TestSupport
#endif

/// The library lock.
extension AppEnvironment {
    /// The one lock, already decided for launch (locked when on), so no view is built before it covers the library.
    /// `-Lock on` turns the lock on (`makeKept`), `-LockAfter` sets the relock time and `-Authenticator` scripts Face ID.
    static func makeLock(options: LaunchOptions, preferences: AppPreferences) -> LibraryLock {
        let lock = LibraryLock(
            preferences: preferences,
            authenticator: authenticator(options: options),
            relockAfter: options.relockSeconds.map { .seconds($0) } ?? LibraryLock.relockAfter)
        lock.launched()
        return lock
    }

    /// Face ID through LocalAuthentication, or scripted answers for `-Authenticator`, so a UI test never sees the
    /// system prompt.
    private static func authenticator(options: LaunchOptions) -> any DeviceAuthenticating {
        #if DEBUG
            if let flag = options.authenticator { return fakeAuthenticator(flag) }
        #endif
        return SystemAuthenticator()
    }

    #if DEBUG
        private static func fakeAuthenticator(_ flag: AuthenticatorFlag) -> FakeAuthenticator {
            switch flag {
            case .succeeds: FakeAuthenticator(availability: .biometrics, results: [.success])
            case .succeedsOnce: FakeAuthenticator(availability: .biometrics, results: [.success, .cancelled])
            case .cancels: FakeAuthenticator(availability: .biometrics, results: [.cancelled])
            case .cancelsOnce: FakeAuthenticator(availability: .biometrics, results: [.cancelled, .success])
            case .cancelsSecond:
                FakeAuthenticator(availability: .biometrics, results: [.success, .cancelled, .success])
            case .fails: FakeAuthenticator(availability: .biometrics, results: [.failed])
            case .passcodeOnly: FakeAuthenticator(availability: .passcodeOnly, results: [.success])
            case AuthenticatorFlag.none: FakeAuthenticator(availability: .none)
            }
        }
    #endif
}
