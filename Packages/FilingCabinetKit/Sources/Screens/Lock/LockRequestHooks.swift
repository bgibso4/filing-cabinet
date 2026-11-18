import Core
import ScreenModels
import SwiftUI

/// What the lock and the requests from outside the app hear of each other at the root.
struct LockRequestHooks: ViewModifier {
    let lock: LibraryLock
    let requests: ExternalRequests
    let flow: ScanFlowModel

    func body(content: Content) -> some View {
        content
            // The lock hears of a Scan request at once, not when the scan can start: launch may not have finished, and
            // a Face ID try that ends meanwhile must not open the library behind the scan.
            .onChange(of: requests.pending, initial: true) { _, pending in
                if pending == .scan { lock.outsideScanRequested() }
            }
            // A cancelled or failed Face ID drops a waiting search or open: a later unlock never acts on it. A Scan
            // request never waits for the lock, so it is left alone.
            .onChange(of: lock.refusals) {
                if let pending = requests.pending, pending != .scan { _ = requests.take() }
            }
            // Camera access is off, so the scan never opened its capture layer. Locked, that is an ordinary arrival:
            // Face ID runs, and the message is there once the library opens.
            .onChange(of: flow.phase == .cameraOff) { _, isOff in
                if isOff { Task { await lock.outsideScanCouldNotStart() } }
            }
    }
}
