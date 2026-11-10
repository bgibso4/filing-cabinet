import SwiftUI
import UIKit

/// Takes the navigation bar of the stack it sits in out of the accessibility tree while `isHidden` (the capture layer
/// is up): the bar's title is the system's own (plan 3, E9), outside every screen's view, so a screen's hiding doesn't
/// reach it, and no SwiftUI modifier on the stack does either (tried: `accessibilityHidden` on the stack, and the
/// layer as a modal).
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
