import Core
import TestSupport
import Testing

@testable import ScreenModels

// A scan from outside (the Scan control, the Action button, Siri) never waits for, triggers or counts as an unlock.

@MainActor @Test func aLockedArrivalWithAScanPendingMakesNoTryAndShowsUnlock() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: true)
    #expect(rig.authenticator.reasons.isEmpty)
    #expect(rig.lock.isLocked)
    rig.lock.outsideScanStarted()
    // The scan ends at the cover, with the button: no try of its own afterwards.
    await rig.lock.becameActive(scanIsPending: false)
    #expect(rig.authenticator.reasons.isEmpty)
    #expect(rig.lock.isLocked)
    #expect(rig.lock.showsUnlock)
    #expect(rig.lock.refusals == 0)
}

@MainActor @Test func aTryInFlightWhenAScanStartsNeverUnlocks() async throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let gate = GatedAuthenticator()
    let lock = gatedLock(fresh, gate, LockRig.ClockBox())
    lock.launched()
    let first = Task { await lock.becameActive(scanIsPending: false) }
    while gate.calls == 0 { await Task.yield() }
    lock.outsideScanStarted()
    gate.answer(.success)
    await first.value
    #expect(lock.isLocked)
    #expect(lock.showsUnlock)
    #expect(lock.refusals == 0)
    await lock.becameActive(scanIsPending: false)
    #expect(gate.calls == 1)
}

@MainActor @Test func aScanFromOutsideLeavesAnUnlockedLibraryOpen() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    #expect(!rig.lock.isLocked)
    rig.lock.outsideScanStarted()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.showsUnlock)
    #expect(rig.authenticator.reasons.count == 1)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
}

@MainActor @Test func aScanFromOutsideWithTheLockOffChangesNothing() async throws {
    let rig = try LockRig(lockOn: false)
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: true)
    rig.lock.outsideScanStarted()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.showsUnlock)
    #expect(rig.authenticator.reasons.isEmpty)
}

@MainActor @Test func unlockAfterALockedScanOpensTheLibrary() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: true)
    rig.lock.outsideScanStarted()
    await rig.lock.unlock()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.showsUnlock)
    #expect(rig.authenticator.reasons.count == 1)
}

@MainActor @Test func aRequestSeenWhileATryIsInFlightNeverUnlocks() async throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let gate = GatedAuthenticator()
    let lock = gatedLock(fresh, gate, LockRig.ClockBox())
    lock.launched()
    let first = Task { await lock.becameActive(scanIsPending: false) }
    while gate.calls == 0 { await Task.yield() }
    // The request lands before launch has finished: the root can't start the scan yet, but tells the lock at once.
    lock.outsideScanRequested()
    gate.answer(.success)
    await first.value
    #expect(lock.isLocked)
    #expect(lock.showsUnlock)
    #expect(lock.refusals == 0)
    lock.outsideScanStarted()
    await lock.becameActive(scanIsPending: false)
    #expect(gate.calls == 1)
    #expect(lock.isLocked)
}

@MainActor @Test func aRequestSeenWhileUnlockedChangesNothing() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.outsideScanRequested()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.showsUnlock)
}

// What passes through the shield: only the capture layer of a scan started from outside while locked, and only once its
// cover is on screen. A capture layer left open by an unlocked scan is covered like everything else (ruling R10).

@MainActor @Test func theShieldStaysUpUntilTheLockedScansCoverIsOnScreen() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: true)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    rig.lock.outsideScanStarted()
    // The scan has started, but its cover isn't up yet: whatever the app had presented is still what shows.
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: false))
    rig.lock.captureLayerClosed()
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: false, sceneIsActive: true))
    #expect(rig.lock.isLocked)
}

@MainActor @Test func aLockedScansCameraOnAReturnMakesNoTry() async throws {
    let rig = try LockRig(results: [.cancelled, .success])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: true)
    rig.lock.outsideScanStarted()
    rig.lock.leftForeground()
    await rig.lock.becameActive(scanIsPending: false)
    #expect(rig.authenticator.reasons.isEmpty)
    #expect(rig.lock.isLocked)
    #expect(rig.lock.showsUnlock)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
}

@MainActor @Test func aCaptureLayerLeftOpenIsCoveredAfterARelockAndFaceIDRuns() async throws {
    let rig = try LockRig(results: [.success, .cancelled, .success])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    // A scan started while unlocked (Home's Scan, or from outside) is in review; the app is left for the relock time.
    rig.lock.outsideScanStarted()
    rig.lock.leftForeground()
    rig.advance(300)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
    await rig.lock.becameActive(scanIsPending: false)
    #expect(rig.authenticator.reasons.count == 2)
    #expect(rig.lock.isLocked)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
    // A Scan request now finds the review open: the root starts nothing, and the review stays covered.
    rig.lock.outsideScanRequested()
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
    await rig.lock.unlock()
    #expect(!rig.lock.isLocked)
    #expect(!rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
}

@MainActor @Test func unlockingEndsWhatALockedScanLetThrough() async throws {
    let rig = try LockRig(results: [.success, .cancelled])
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: true)
    // Started locked, but the camera is off, so no capture layer ever opens or closes.
    rig.lock.outsideScanStarted()
    await rig.lock.unlock()
    #expect(!rig.lock.isLocked)
    // Later a scan from Home is left open past the relock time: it is covered.
    rig.lock.leftForeground()
    rig.advance(300)
    await rig.lock.becameActive(scanIsPending: false)
    #expect(rig.lock.isLocked)
    #expect(rig.lock.shieldIsUp(captureCoverIsUp: true, sceneIsActive: true))
}
