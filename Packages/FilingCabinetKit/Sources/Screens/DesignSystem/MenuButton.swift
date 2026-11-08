import SwiftUI
import UIKit

/// A system menu over a SwiftUI row: a clear `UIButton` that opens `menu` on tap. It is the row's one accessibility
/// element, carrying the identifier, label and value. SwiftUI's `Menu` would add a second, unidentified button inside
/// its own; the row it covers should be hidden from accessibility.
struct MenuButton: UIViewRepresentable {
    let label: String
    let value: String
    let identifier: String
    /// Rebuilt on every update, so each action sees the current choices.
    let menu: () -> UIMenu

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.showsMenuAsPrimaryAction = true
        // The menu reads top to bottom wherever it opens.
        button.preferredMenuElementOrder = .fixed
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = menu()
        button.isEnabled = context.environment.isEnabled
        button.accessibilityIdentifier = identifier
        button.accessibilityLabel = label
        button.accessibilityValue = value
    }
}
