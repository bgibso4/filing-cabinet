import SwiftUI

/// Draws the label as it is, enabled or not: the label's own colours already say when it can't be tapped. An enabled
/// button dims while it is pressed, as `.plain` does; a disabled one never changes.
struct UnfadedButtonStyle: ButtonStyle {
    private static let pressedOpacity = 0.6

    @Environment(\.isEnabled) private var isEnabled

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        // A branch rather than `.opacity(1)` at rest: an opacity modifier, even at 1, makes the accessibility audit
        // report the label's contrast as failed.
        if isEnabled && configuration.isPressed {
            configuration.label.opacity(Self.pressedOpacity)
        } else {
            configuration.label
        }
    }
}
