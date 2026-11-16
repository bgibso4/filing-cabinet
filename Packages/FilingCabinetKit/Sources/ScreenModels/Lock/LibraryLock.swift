import Core
import Foundation
import Observation

/// The library lock: when the cover is up, when Face ID is tried and when the library locks again. Timing uses only
/// the injected `now`, never the date.
@MainActor
@Observable
public final class LibraryLock {
    public static let relockAfter = Duration.seconds(300)

    /// The cover is up. False whenever the lock is off or paused.
    public private(set) var isLocked = false
    /// The cover shows its Unlock button: the last try was cancelled or failed.
    public private(set) var showsUnlock = false
    /// Bumped each time a try ends cancelled or failed (the root drops a waiting request).
    public private(set) var refusals = 0
    /// The lock was on as the scene went to the background, and `arrived()` hasn't yet decided whether the time away
    /// relocks it. The shield stays up meanwhile, so the first active frame never shows the library.
    private var arrivalIsPending = false

    /// The person's wish is on and the phone can check (Face ID or a passcode).
    public var isOn: Bool { preferences.lockOn && authenticator.availability() != .none }
    /// The wish is on but the phone has no passcode: the library opens.
    public var isPaused: Bool { preferences.lockOn && authenticator.availability() == .none }
    /// What the phone can check now, for Settings.
    public var availability: AuthenticationAvailability { authenticator.availability() }

    /// The shield above every window the app shows is up: while locked, unless the capture layer a Scan request opened
    /// is up in an active scene; and whenever the lock is on and the scene isn't active, so the app switcher's snapshot
    /// never shows the library, even inside the relock time.
    /// Back from the background, it stays up until `arrived()` has run.
    package func shieldIsUp(captureLayerIsUp: Bool, sceneIsActive: Bool) -> Bool {
        if isOn, !sceneIsActive || arrivalIsPending { return true }
        return isLocked && !captureLayerIsUp
    }

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let authenticator: any DeviceAuthenticating
    @ObservationIgnored private let now: @MainActor () -> ContinuousClock.Instant
    @ObservationIgnored private let relockAfter: Duration
    /// When the scene went to the background; nil while it has not been away since it last became active.
    @ObservationIgnored private var leftAt: ContinuousClock.Instant?
    /// How many times the scene has left the foreground, or a scan from outside started while locked; a check that ends
    /// after either doesn't unlock.
    @ObservationIgnored private var interruptions = 0
    /// A check is running (a try, the Unlock button or the Settings switch).
    @ObservationIgnored private var isChecking = false
    /// Face ID has been tried since the library was last launched or came back from the background.
    @ObservationIgnored private var triedThisArrival = false

    public init(
        preferences: AppPreferences,
        authenticator: any DeviceAuthenticating,
        now: @escaping @MainActor () -> ContinuousClock.Instant = { ContinuousClock.now },
        relockAfter: Duration = LibraryLock.relockAfter
    ) {
        self.preferences = preferences
        self.authenticator = authenticator
        self.now = now
        self.relockAfter = relockAfter
    }

    /// At launch, before the first frame: locks when on.
    public func launched() {
        isLocked = isOn
    }

    /// The scene went to `.background`.
    public func leftForeground() {
        leftAt = now()
        interruptions += 1
        triedThisArrival = false
        arrivalIsPending = isOn
    }

    /// The scene became `.active`: at once, with no wait, locks when it was away `relockAfter` or longer. Called
    /// before the Face ID try starts, so the shield decides on the first active frame. A second call with nothing new
    /// changes nothing.
    public func arrived() {
        arrivalIsPending = false
        let away = leftAt
        leftAt = nil
        guard isOn else {
            isLocked = false
            showsUnlock = false
            return
        }
        if let away, now() - away >= relockAfter { isLocked = true }
    }

    /// The scene became `.active`: `arrived()`, then tries Face ID once per arrival (launch, or back from the
    /// background). A try already running or already made is not repeated. `scanIsPending`: a Scan request from outside
    /// is waiting or the capture layer is up; a scan never triggers an unlock, so no try is made and the cover it ends
    /// at shows Unlock.
    public func becameActive(scanIsPending: Bool) async {
        arrived()
        guard isLocked, !isChecking, !triedThisArrival else { return }
        triedThisArrival = true
        if scanIsPending {
            showsUnlock = true
            return
        }
        await tryUnlock()
    }

    /// The root started a scan for a request from outside (the Scan control, the Action button, Siri). Locked, the scan
    /// ends at the cover with Unlock: no try is made for the rest of this arrival, and a try already running can't
    /// unlock. An open library stays open.
    public func outsideScanStarted() {
        guard isLocked else { return }
        triedThisArrival = true
        showsUnlock = true
        interruptions += 1
    }

    /// The Unlock button.
    public func unlock() async {
        guard isLocked, !isChecking else { return }
        await tryUnlock()
    }

    /// The Settings switch. Both directions check the owner first, except turning off while paused.
    /// Returns whether the setting changed.
    package func setOn(_ isOn: Bool) async -> Bool {
        guard isOn != preferences.lockOn, !isChecking else { return false }
        if isOn {
            guard availability != .none, await check() == .success else { return false }
            preferences.lockOn = true
            leftAt = nil
            return true
        }
        if !isPaused {
            guard await check() == .success else { return false }
        }
        preferences.lockOn = false
        isLocked = false
        showsUnlock = false
        return true
    }

    private func tryUnlock() async {
        let interruptionsBefore = interruptions
        let result = await check()
        // A success that arrives after the app left, or after a scan from outside started, says nothing about who holds
        // the phone now and must not open the library behind the scan: the button decides.
        switch result {
        case .success where interruptions == interruptionsBefore:
            isLocked = false
            showsUnlock = false
        case .success:
            showsUnlock = true
        case .cancelled, .failed:
            showsUnlock = true
            refusals += 1
        }
    }

    private func check() async -> AuthenticationResult {
        isChecking = true
        defer { isChecking = false }
        return await authenticator.authenticate(reason: String(localized: "Unlock your library", bundle: #bundle))
    }
}
