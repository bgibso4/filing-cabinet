import SwiftUI

/// Draws the label as it is, enabled or not: the label's own colours already say when it can't be tapped.
struct UnfadedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
