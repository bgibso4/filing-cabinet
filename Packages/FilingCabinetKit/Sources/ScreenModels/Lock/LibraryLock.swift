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
    /// The cover shows its Unlock button: the last try was cancelled or failed, ended too late to count, or wasn't
    /// made because a scan from outside came with the arrival.
    public private(set) var showsUnlock = false
    /// Bumped each time a try ends cancelled or failed (the root drops a waiting request).
    public private(set) var refusals = 0
    /// The lock was on as the scene went to the background, and neither `comingBack()` nor `arrived()` has yet decided
    /// whether the time away relocks it. The shield stays up meanwhile, so no frame of the return shows a library that
    /// should be locked.
    private var arrivalIsPending = false
    /// A scan from outside started while the library was locked, and its capture layer hasn't closed: the one thing
    /// that shows through the shield. A scan started while unlocked never sets it, so left open it is covered.
    private var scanIsLetThrough = false

    /// The person's wish is on and the phone can check (Face ID or a passcode).
    public var isOn: Bool { preferences.lockOn && authenticator.availability() != .none }
    /// The wish is on but the phone has no passcode: the library opens.
    public var isPaused: Bool { preferences.lockOn && authenticator.availability() == .none }
    /// What the phone can check now, for Settings.
    public var availability: AuthenticationAvailability { authenticator.availability() }

    /// The shield above every window the app shows is up: while locked, unless a scan let through the lock
    /// (`outsideScanStarted()`) has its cover on screen; and, with the lock on, from the moment the scene is in the
    /// background until it is on its way back (`comingBack()`, or `arrived()`), so the app switcher's snapshot never
    /// shows the library, even inside the relock time. A scene that is only inactive isn't covered: the cover would
    /// flash on every trip out of the app and back.
    /// `captureCoverIsUp`: the capture layer's cover has finished appearing and nothing else the app presented is left
    /// under it. Until then the shield stays, so whatever was showing when the scan was asked for is never seen.
    package func shieldIsUp(captureCoverIsUp: Bool) -> Bool {
        if isOn, arrivalIsPending { return true }
        return isLocked && !(scanIsLetThrough && captureCoverIsUp)
    }

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let authenticator: any DeviceAuthenticating
    @ObservationIgnored private let now: @MainActor () -> ContinuousClock.Instant
    @ObservationIgnored private let relockAfter: Duration
    /// When the scene first went to the background since it was last active; nil while it has not been away.
    @ObservationIgnored private var leftAt: ContinuousClock.Instant?
    /// How many times the scene has left the foreground, or a scan from outside was asked for while locked; a check that
    /// ends after either doesn't unlock.
    @ObservationIgnored private var interruptions = 0
    /// A check is running (a try, the Unlock button or the Settings switch).
    @ObservationIgnored private var isChecking = false
    /// This arrival (launch, or back from the background) has had its one automatic Face ID try, or gave it up to a scan
    /// from outside.
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

    /// The scene went to `.background`. A second time without becoming active in between (background, inactive,
    /// background) keeps the first departure time. The wish, not `isOn`, keeps the shield up for the return: a passcode
    /// may be set while away.
    public func leftForeground() {
        leftAt = leftAt ?? now()
        interruptions += 1
        triedThisArrival = false
        arrivalIsPending = preferences.lockOn
    }

    /// The scene left `.background` for the foreground, before it is active: at once, locks when it was away
    /// `relockAfter` or longer, and otherwise lets the shield drop, so a quick trip out and back never shows the cover.
    /// The departure time is kept: the system may wake the app and send it back without it ever becoming active.
    public func comingBack() {
        guard arrivalIsPending else { return }
        arrivalIsPending = false
        if isOn, let leftAt, now() - leftAt >= relockAfter { isLocked = true }
    }

    /// The scene became `.active`: at once, with no wait, locks when it was away `relockAfter` or longer. Called
    /// before the Face ID try starts, so the shield decides on the first active frame. A second call with nothing new
    /// changes nothing.
    public func arrived() {
        arrivalIsPending = false
        let away = leftAt
        leftAt = nil
        guard isOn else { return open() }
        if let away, now() - away >= relockAfter { isLocked = true }
    }

    /// The scene became `.active`: `arrived()`, then tries Face ID once per arrival (launch, or back from the
    /// background). A try already running or already made is not repeated. `scanIsPending`: a Scan request from outside
    /// is waiting. A scan never triggers an unlock, so with one waiting, or one let through the lock still open, no try
    /// is made and the cover it ends at shows Unlock. A capture layer left open by an unlocked scan is no reason to
    /// skip the try: unlocking returns to it.
    public func becameActive(scanIsPending: Bool) async {
        arrived()
        guard isLocked, !isChecking, !triedThisArrival else { return }
        triedThisArrival = true
        if scanIsPending || scanIsLetThrough {
            showsUnlock = true
            return
        }
        await tryUnlock()
    }

    /// A Scan request from outside (the Scan control, the Action button, Siri) has arrived; the root says so at once,
    /// before it can start the scan. Locked, the scan will end at the cover with Unlock: no try is made for the rest of
    /// this arrival, and a try already running can't unlock. An open library stays open.
    public func outsideScanRequested() {
        guard isLocked else { return }
        triedThisArrival = true
        showsUnlock = true
        interruptions += 1
    }

    /// The root started the scan for that request. Locked, its capture layer is let through the shield until it closes
    /// (`captureLayerClosed()`); the library stays locked behind it. An open library stays open.
    public func outsideScanStarted() {
        outsideScanRequested()
        scanIsLetThrough = isLocked
    }

    /// The capture layer has closed, saved or not: nothing is let through the shield any more.
    public func captureLayerClosed() {
        scanIsLetThrough = false
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
            return true
        }
        if !isPaused {
            guard await check() == .success else { return false }
        }
        preferences.lockOn = false
        open()
        return true
    }

    private func tryUnlock() async {
        let interruptionsBefore = interruptions
        let result = await check()
        // A success that arrives after the app left, or after a scan from outside started, says nothing about who holds
        // the phone now and must not open the library behind the scan: the button decides.
        switch result {
        case .success where interruptions == interruptionsBefore:
            open()
        case .success:
            showsUnlock = true
        case .cancelled, .failed:
            showsUnlock = true
            refusals += 1
        }
    }

    /// The cover goes. Nothing is let through a lock that is open.
    private func open() {
        isLocked = false
        showsUnlock = false
        scanIsLetThrough = false
    }

    private func check() async -> AuthenticationResult {
        isChecking = true
        defer { isChecking = false }
        return await authenticator.authenticate(reason: String(localized: "Unlock your library", bundle: #bundle))
    }
}
