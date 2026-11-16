import Core
import Synchronization
import TestSupport
import Testing

@testable import ScreenModels

/// A phone whose check stays open until the test answers it.
private final class GatedAuthenticator: DeviceAuthenticating {
    private let state = Mutex<(calls: Int, waiting: [CheckedContinuation<AuthenticationResult, Never>])>((0, []))
    var calls: Int { state.withLock { $0.calls } }
    func availability() -> AuthenticationAvailability { .biometrics }
    func authenticate(reason: String) async -> AuthenticationResult {
        await withCheckedContinuation { continuation in
            state.withLock {
                $0.calls += 1
                $0.waiting.append(continuation)
            }
        }
    }
    func answer(_ result: AuthenticationResult) {
        state.withLock {
            if !$0.waiting.isEmpty { $0.waiting.removeFirst().resume(returning: result) }
        }
    }
}

@MainActor
private final class LockRig {
    let fresh: FreshDefaults
    let preferences: AppPreferences
    let authenticator: FakeAuthenticator
    let lock: LibraryLock
    init(
        lockOn: Bool = true,
        availability: AuthenticationAvailability = .biometrics,
        results: [AuthenticationResult] = [.success]
    ) throws {
        fresh = try FreshDefaults()
        preferences = AppPreferences(defaults: fresh.defaults)
        preferences.lockOn = lockOn
        authenticator = FakeAuthenticator(availability: availability, results: results)
        let box = ClockBox()
        clock = box
        lock = LibraryLock(preferences: preferences, authenticator: authenticator, now: { box.instant })
    }

    final class ClockBox { var instant = ContinuousClock.now }
    let clock: ClockBox
    func advance(_ seconds: Int) { clock.instant = clock.instant.advanced(by: .seconds(seconds)) }
}

@MainActor @Test func offNeverLocksNorAsks() async throws {
    let rig = try LockRig(lockOn: false)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)
    #expect(rig.authenticator.reasons.isEmpty)
}

@MainActor @Test func onLocksAtLaunchAndUnlocksOnSuccess() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    #expect(rig.lock.isLocked)
    #expect(!rig.lock.showsUnlock)
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)
    #expect(rig.authenticator.reasons == ["Unlock your library"])
}

@MainActor @Test(arguments: [AuthenticationResult.cancelled, .failed])
func refusalShowsUnlockAndIsNotRepeated(result: AuthenticationResult) async throws {
    let rig = try LockRig(results: [result, .success])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    #expect(rig.lock.isLocked)
    #expect(rig.lock.showsUnlock)
    #expect(rig.lock.refusals == 1)
    await rig.lock.becameActive()  // the prompt's own return
    #expect(rig.authenticator.reasons.count == 1)
    await rig.lock.unlock()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.showsUnlock)
    #expect(rig.authenticator.reasons.count == 2)
}

@MainActor @Test func secondActiveWhileFirstAwaitsMakesNoSecondCall() async throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let preferences = AppPreferences(defaults: fresh.defaults)
    preferences.lockOn = true
    let gate = GatedAuthenticator()
    let lock = LibraryLock(preferences: preferences, authenticator: gate)
    lock.launched()
    let first = Task { await lock.becameActive() }
    while gate.calls == 0 { await Task.yield() }
    await lock.becameActive()
    #expect(gate.calls == 1)
    gate.answer(.success)
    await first.value
    #expect(!lock.isLocked)
}

@MainActor @Test func relocksOnlyAfterTheFullTime() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    rig.lock.leftForeground()
    rig.advance(299)
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)
    #expect(rig.authenticator.reasons.count == 1)
    rig.lock.leftForeground()
    rig.advance(300)
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)  // the fake succeeds, so it opened again
    #expect(rig.authenticator.reasons.count == 2)
}

@MainActor @Test func exactlyFiveMinutesLocks() async throws {
    let rig = try LockRig(results: [.success, .cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    rig.lock.leftForeground()
    rig.advance(300)
    await rig.lock.becameActive()
    #expect(rig.lock.isLocked)
}

@MainActor @Test func backFromBackgroundWithUnlockShowingTriesAgain() async throws {
    let rig = try LockRig(results: [.cancelled, .success])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    #expect(rig.lock.showsUnlock)
    rig.lock.leftForeground()
    await rig.lock.becameActive()
    #expect(rig.authenticator.reasons.count == 2)
    #expect(!rig.lock.isLocked)
}

@MainActor @Test func neverLeftNeverLocks() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    rig.advance(3_600)
    await rig.lock.becameActive()
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)
    #expect(rig.authenticator.reasons.count == 1)
}

@MainActor @Test func pausedOpensUntilThePhoneCanCheckAgain() async throws {
    let rig = try LockRig(availability: .none)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    #expect(!rig.lock.isLocked)
    #expect(rig.lock.isPaused)
    #expect(!rig.lock.isOn)
    rig.authenticator.currentAvailability = .passcodeOnly
    rig.lock.leftForeground()
    rig.advance(300)
    await rig.lock.becameActive()
    #expect(!rig.lock.isPaused)
    #expect(rig.authenticator.reasons.count == 1)  // it locked, asked, and the fake let it in
}

@MainActor @Test func pausedWhileLockedOpensTheLibrary() async throws {
    let rig = try LockRig(results: [.cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    #expect(rig.lock.isLocked)
    rig.authenticator.currentAvailability = .none
    rig.lock.leftForeground()
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.showsUnlock)
}

@MainActor @Test func passcodeOnlyLocksAndUnlocksLikeBiometrics() async throws {
    let rig = try LockRig(availability: .passcodeOnly)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    #expect(rig.lock.isLocked)
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)
}

@MainActor @Test func turningOnAfterSuccessKeepsLibraryOpen() async throws {
    let rig = try LockRig(lockOn: false)
    defer { rig.fresh.cleanUp() }
    let changed = await rig.lock.setOn(true)
    #expect(changed)
    #expect(rig.preferences.lockOn)
    #expect(!rig.lock.isLocked)
}

@MainActor @Test func turningOnRefusedLeavesItOff() async throws {
    let rig = try LockRig(lockOn: false, results: [.cancelled])
    defer { rig.fresh.cleanUp() }
    let changed = await rig.lock.setOn(true)
    #expect(!changed)
    #expect(!rig.preferences.lockOn)
}

@MainActor @Test func turningOnWithNoPasscodeDoesNotAsk() async throws {
    let rig = try LockRig(lockOn: false, availability: .none)
    defer { rig.fresh.cleanUp() }
    let changed = await rig.lock.setOn(true)
    #expect(!changed)
    #expect(!rig.preferences.lockOn)
    #expect(rig.authenticator.reasons.isEmpty)
}

@MainActor @Test func turningOffChecksTheOwner() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    let changed = await rig.lock.setOn(false)
    #expect(changed)
    #expect(!rig.preferences.lockOn)
    #expect(!rig.lock.isLocked)
    #expect(rig.authenticator.reasons.count == 1)
}

@MainActor @Test func turningOffRefusedStaysOn() async throws {
    let rig = try LockRig(results: [.cancelled])
    defer { rig.fresh.cleanUp() }
    let changed = await rig.lock.setOn(false)
    #expect(!changed)
    #expect(rig.preferences.lockOn)
}

@MainActor @Test func turningOffWhilePausedDoesNotAsk() async throws {
    let rig = try LockRig(availability: .none)
    defer { rig.fresh.cleanUp() }
    let changed = await rig.lock.setOn(false)
    #expect(changed)
    #expect(!rig.preferences.lockOn)
    #expect(rig.authenticator.reasons.isEmpty)
}

@MainActor private func gatedLock(
    _ fresh: FreshDefaults, _ gate: GatedAuthenticator, _ box: LockRig.ClockBox
) -> LibraryLock {
    let preferences = AppPreferences(defaults: fresh.defaults)
    preferences.lockOn = true
    return LibraryLock(preferences: preferences, authenticator: gate, now: { box.instant })
}

@MainActor @Test func aSuccessThatEndsAfterTheAppLeftNeverUnlocks() async throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let gate = GatedAuthenticator()
    let box = LockRig.ClockBox()
    let lock = gatedLock(fresh, gate, box)
    lock.launched()
    let first = Task { await lock.becameActive() }
    while gate.calls == 0 { await Task.yield() }
    lock.leftForeground()
    gate.answer(.success)
    await first.value
    #expect(lock.isLocked)
    box.instant = box.instant.advanced(by: .seconds(300))
    let second = Task { await lock.becameActive() }
    for _ in 0..<50 { await Task.yield() }  // bounded: a missing second call must fail, not hang
    #expect(lock.isLocked)
    gate.answer(.success)
    await second.value
    #expect(!lock.isLocked)
}

@MainActor @Test func aLateSuccessDoesNotClearTheLockTheNextArrivalRaised() async throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let gate = GatedAuthenticator()
    let box = LockRig.ClockBox()
    let lock = gatedLock(fresh, gate, box)
    lock.launched()
    let first = Task { await lock.becameActive() }
    while gate.calls == 0 { await Task.yield() }
    lock.leftForeground()
    box.instant = box.instant.advanced(by: .seconds(300))
    await lock.becameActive()  // a check is still running: raises the lock, asks nothing
    #expect(gate.calls == 1)
    gate.answer(.success)
    await first.value
    #expect(lock.isLocked)
    #expect(lock.showsUnlock)  // the button is the way in
}

// The shield over every window: up while locked unless a Scan request's capture layer is up, and whenever the lock is
// on and the scene isn't active, so the app switcher never shows the library.

@MainActor @Test func shieldIsUpWhileLockedUnlessTheCaptureLayerIs() async throws {
    let rig = try LockRig(results: [.cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    #expect(rig.lock.shieldIsUp(captureLayerIsUp: false, sceneIsActive: true))
    #expect(!rig.lock.shieldIsUp(captureLayerIsUp: true, sceneIsActive: true))
    #expect(rig.lock.shieldIsUp(captureLayerIsUp: true, sceneIsActive: false))
}

@MainActor @Test func shieldCoversTheSwitcherWhileOnEvenWhenUnlocked() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureLayerIsUp: false, sceneIsActive: true))
    #expect(rig.lock.shieldIsUp(captureLayerIsUp: false, sceneIsActive: false))
    #expect(rig.lock.shieldIsUp(captureLayerIsUp: true, sceneIsActive: false))
}

@MainActor @Test(arguments: [(lockOn: false, availability: AuthenticationAvailability.biometrics), (true, .none)])
func shieldNeverShowsWhenOffOrPaused(lockOn: Bool, availability: AuthenticationAvailability) async throws {
    let rig = try LockRig(lockOn: lockOn, availability: availability)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    for sceneIsActive in [true, false] {
        for captureLayerIsUp in [true, false] {
            #expect(!rig.lock.shieldIsUp(captureLayerIsUp: captureLayerIsUp, sceneIsActive: sceneIsActive))
        }
    }
}
