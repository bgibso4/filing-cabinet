import Core
import TestSupport
import Testing

@testable import ScreenModels

// The shield over every window: up while locked, and from the moment the scene is in the background while the lock is
// on, so the app switcher's snapshot never shows the library. A scene that is only inactive (on its way out, the app
// switcher open over it, a system prompt) is not covered: the cover would flash on every trip out and back.
// (What passes through the shield: LibraryLockScanTests.)

@MainActor @Test func shieldIsUpWhileLockedWhateverIsUnderIt() async throws {
    let rig = try LockRig(results: [.cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true))
}

@MainActor @Test func shieldCoversTheSwitchersSnapshotWhileOnEvenWhenUnlocked() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false))
    rig.lock.leftForeground()
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true))
}

// On the way back (the scene leaves the background, before it is active): the shield drops at once inside the relock
// time, so the cover isn't seen on a quick trip out and back, and stays when the time has passed.

@MainActor @Test func comingBackInsideTheRelockTimeDropsTheShieldBeforeTheSceneIsActive() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(299)
    rig.lock.comingBack()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false))
}

@MainActor @Test func comingBackAfterTheRelockTimeLocksAndKeepsTheShield() async throws {
    let rig = try LockRig(results: [.success, .cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(300)
    rig.lock.comingBack()
    #expect(rig.lock.isLocked)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
}

// Background, inactive, background (the system wakes the app without showing it): the time away still counts from the
// first departure, and the shield is up again for the snapshot.

@MainActor @Test func comingBackWithoutArrivingKeepsTheFirstDepartureTime() async throws {
    let rig = try LockRig(results: [.success, .cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(200)
    rig.lock.comingBack()
    rig.lock.leftForeground()
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
    rig.advance(100)
    rig.lock.arrived()
    #expect(rig.lock.isLocked)
}

@MainActor @Test(arguments: [(lockOn: false, availability: AuthenticationAvailability.biometrics), (true, .none)])
func shieldNeverShowsWhenOffOrPaused(lockOn: Bool, availability: AuthenticationAvailability) async throws {
    let rig = try LockRig(lockOn: lockOn, availability: availability)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    for captureCoverIsUp in [true, false] {
        #expect(!rig.lock.shieldIsUp(captureCoverIsUp: captureCoverIsUp))
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
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
    rig.lock.arrived()
    #expect(rig.lock.isLocked)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
}

@MainActor @Test func backInsideTheRelockTimeTheShieldDropsOnceArrived() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(299)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
    rig.lock.arrived()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false))
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
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false))
    rig.lock.arrived()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false))
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
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
    rig.lock.arrived()
    #expect(rig.lock.isLocked)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false))
}
