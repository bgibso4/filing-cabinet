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
    #expect(!rig.lock.shieldIsUp(captureLayerIsUp: false, sceneIsActive: true))
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

@MainActor @Test func theCameraUpOnAReturnPastTheRelockTimeMakesNoTry() async throws {
    let rig = try LockRig()
    defer { rig.fresh.cleanUp() }
    rig.lock.launched()
    await rig.lock.becameActive(scanIsPending: false)
    rig.lock.leftForeground()
    rig.advance(300)
    await rig.lock.becameActive(scanIsPending: true)
    #expect(rig.lock.isLocked)
    #expect(rig.lock.showsUnlock)
    #expect(rig.authenticator.reasons.count == 1)
}
