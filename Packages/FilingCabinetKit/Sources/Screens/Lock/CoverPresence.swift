import SwiftUI
import UIKit

/// Tells the root when the full-screen cover it sits in is really on screen: its presentation has finished and it is
/// the only thing the app's window has presented, so nothing else the app showed is left above or under it. An empty
/// background of the capture layer; the lock's shield comes down for a scan only once this says so, never when the
/// scan merely starts (the cover can't go up until what was presented before it has gone).
struct CoverPresence: UIViewControllerRepresentable {
    let onChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> Probe {
        Probe()
    }

    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.onChange = onChange
    }

    /// Reports the cover's own appearance: UIKit calls these when its presentation has finished and when it has gone.
    final class Probe: UIViewController {
        var onChange: (Bool) -> Void = { _ in }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onChange(isPresentedByTheWindowsRoot)
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            onChange(false)
        }

        /// The cover (this probe's outermost parent) was presented by the window's root itself, so no sheet or other
        /// cover sits between them.
        private var isPresentedByTheWindowsRoot: Bool {
            var cover: UIViewController = self
            while let parent = cover.parent { cover = parent }
            guard let presenter = cover.presentingViewController else { return false }
            return presenter === view.window?.rootViewController
        }
    }
}
