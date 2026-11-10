import SwiftUI
import UIKit

/// Takes the navigation bar of the stack it sits in out of the accessibility tree while `isHidden` (the capture layer
/// is up): the bar's title is the system's own (plan 3, E9), outside every screen's view, so a screen's hiding doesn't
/// reach it, and no SwiftUI modifier on the stack does either (tried: `accessibilityHidden` on the stack, and the
/// layer as a modal). It restores the bar only through its own `isHidden`, so it must stay on the stack's root (an
/// unconditional `.background`, never behind an `if`): off the stack while hidden, the bar would stay out of the tree.
struct BarHiddenFromAccessibility: UIViewControllerRepresentable {
    let isHidden: Bool

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isHidden = isHidden
    }

    final class Controller: UIViewController {
        var isHidden = false {
            didSet { apply() }
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        private func apply() {
            navigationController?.navigationBar.accessibilityElementsHidden = isHidden
        }
    }
}
