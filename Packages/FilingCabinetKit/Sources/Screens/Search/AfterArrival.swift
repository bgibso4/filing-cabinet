import SwiftUI
import UIKit

/// Runs `action` once the screen it sits on has finished arriving: UIKit's `viewDidAppear`, which comes after a
/// cover's slide or a push has ended, where SwiftUI's `onAppear` comes as it starts. Search focuses its field here so
/// the keyboard rises after Search has, not racing it (B17, round 2).
struct AfterArrival: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller(action: action)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.action = action
    }

    final class Controller: UIViewController {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            action()
        }
    }
}
