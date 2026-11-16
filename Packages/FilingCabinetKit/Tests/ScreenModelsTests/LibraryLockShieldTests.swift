import Core
import TestSupport
import Testing

@testable import ScreenModels

// The shield over every window: up while locked, and whenever the lock is on and the scene isn't active, so the app
// switcher never shows the library. (What passes through it: LibraryLockScanTests.)

@MainActor @Test func shieldIsUpWhileLockedWhateverIsUnderIt() async throws {
    let rig = try LockRig(results: [.cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: false))
}

@MainActor @Test func shieldCoversTheSwitcherWhileOnEvenWhenUnlocked() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: false))
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: false))
}

@MainActor @Test(arguments: [(lockOn: false, availability: AuthenticationAvailability.biometrics), (true, .none)])
func shieldNeverShowsWhenOffOrPaused(lockOn: Bool, availability: AuthenticationAvailability) async throws {
    let rig = try LockRig(lockOn: lockOn, availability: availability)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    for sceneIsActive in [true, false] {
        for captureCoverIsUp in [true, false] {
            #expect(!rig.lock.shieldIsUp(captureCoverIsUp: captureCoverIsUp, sceneIsActive: sceneIsActive))
        }
    }
}

// Back from the background: the shield stays up from the first active render until `arrived()` has decided, at once
// and without waiting for Face ID, whether the relock time has passed. No frame of the library shows in between.

@MainActor @Test func backAfterTheRelockTimeTheShieldNeverDrops() async throws {
    let rig = try LockRig(results: [.success, .cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(300)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    rig.lock.arrived()
    #expect(rig.lock.isLocked)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
}

@MainActor @Test func backInsideTheRelockTimeTheShieldDropsOnceArrived() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(299)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    rig.lock.arrived()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
}

@MainActor @Test func arrivingTwiceLocksOnceAndAsksOnce() async throws {
    let rig = try LockRig(results: [.success, .cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(300)
    rig.lock.arrived()
    rig.lock.arrived()
    #expect(rig.lock.isLocked)
    await rig.lock.becameActive(scanIsPending: false)
    #expect(rig.authenticator.reasons.count == 2)
    #expect(rig.lock.showsUnlock)
}

@MainActor @Test(arguments: [(lockOn: false, availability: AuthenticationAvailability.biometrics), (true, .none)])
func backFromTheBackgroundOffOrPausedNeverRaisesTheShield(
    lockOn: Bool, availability: AuthenticationAvailability
) async throws {
    let rig = try LockRig(lockOn: lockOn, availability: availability)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(300)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    rig.lock.arrived()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
}

// The wish, not what the phone could check on leaving, keeps the shield up for the return.

@MainActor @Test func aPasscodeAddedWhileAwayKeepsTheShieldUpUntilArrived() async throws {
    let rig = try LockRig(availability: .none, results: [.cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    #expect(rig.lock.isPaused)
    rig.lock.leftForeground()
    rig.authenticator.currentAvailability = .passcodeOnly
    rig.advance(300)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    rig.lock.arrived()
    #expect(rig.lock.isLocked)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
}
