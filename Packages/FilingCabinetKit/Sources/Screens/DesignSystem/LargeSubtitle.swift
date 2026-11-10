import SwiftUI
import UIKit

/// Sets the large subtitle of the navigation item of the screen it sits in, in the design's subheadline (plan 3, E9):
/// UIKit draws `navigationSubtitle` under the large title at the small subtitle's size. The item's attributed large
/// subtitle wins over the string SwiftUI sets, and the bar carries it with the item through a push or pop.
struct LargeSubtitle: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.text = text
    }

    final class Controller: UIViewController {
        var text = "" {
            didSet { if text != oldValue { apply() } }
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        /// The item is the one of the screen's controller: the ancestor the navigation controller holds.
        private func apply() {
            let screen = sequence(first: self as UIViewController, next: \.parent).first {
                $0.parent is UINavigationController
            }
            guard let screen else { return }
            var subtitle = AttributedString(text)
            subtitle.uiKit.font = HeaderAppearance.largeSubtitleFont
            subtitle.uiKit.foregroundColor = HeaderAppearance.subtitleColor
            screen.navigationItem.largeAttributedSubtitle = subtitle
        }
    }
}
