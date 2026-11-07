import Core
import ScreenModels
import SwiftUI
import UIKit

/// The Expiry row and its menu: the collection default, every lifespan and "Choose a date…", which opens a
/// calendar. Off, with secondary text, until a collection is chosen.
struct ExpiryMenu: View {
    let model: ReviewModel

    @State private var isChoosingDate = false

    private static var label: String { String(localized: "Expiry", bundle: #bundle) }

    var body: some View {
        ReviewRow(label: Self.label, value: model.expiryValue) {
            Image(systemName: "hourglass")
                // Title 2 is closest to the mock's 26 by 24 pt glyph.
                .font(Tokens.Typography.title2.weight(.regular))
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .accessibilityHidden(true)
        .overlay {
            MenuButton(
                label: Self.label, value: model.expiryValue, identifier: AccessibilityID.Review.expiry, menu: menu)
        }
        .disabled(!model.isExpiryEnabled)
        .sheet(isPresented: $isChoosingDate) {
            ExpiryDateSheet(model: model)
        }
    }

    /// The choices, then "Choose a date…" in a section of its own.
    private func menu() -> UIMenu {
        let choices = model.expiryOptions.map { option in
            let action = UIAction(title: option.label, subtitle: option.detail) { _ in
                model.chooseExpiry(option.override)
            }
            action.state = option.isSelected ? .on : .off
            return action
        }
        let chooseDate = UIAction(title: String(localized: "Choose a date…", bundle: #bundle)) { _ in
            isChoosingDate = true
        }
        return UIMenu(children: [
            UIMenu(options: .displayInline, children: choices),
            UIMenu(options: .displayInline, children: [chooseDate]),
        ])
    }
}
