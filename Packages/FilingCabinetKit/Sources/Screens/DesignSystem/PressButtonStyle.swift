import SwiftUI

/// Home's rows and favourite cards while a finger is down (B18): they shrink a little and settle back on lift; with
/// Reduce Motion they dim instead. The grids' tiles have no press of their own to match (`.plain`).
struct PressButtonStyle: ButtonStyle {
    // B18 (Ben: "a very minor animation"). My calls: 3 % smaller, in and out over 0.15 s; dimmed as
    // UnfadedButtonStyle dims. No motion tokens exist in design/tokens.json.
    private static let pressedScale: CGFloat = 0.97
    private static let pressedOpacity = 0.6
    private static var press: Animation { .easeOut(duration: 0.15) }

    @Environment(\.reducesMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        return dimmed(configuration.label, isPressed && reduceMotion)
            .scaleEffect(isPressed && !reduceMotion ? Self.pressedScale : 1)
            .animation(reduceMotion ? nil : Self.press, value: isPressed)
    }

    /// A branch rather than `.opacity(1)` at rest: an opacity modifier, even at 1, makes the accessibility audit report
    /// the label's contrast as failed (UnfadedButtonStyle).
    @ViewBuilder
    private func dimmed(_ label: Configuration.Label, _ isDimmed: Bool) -> some View {
        if isDimmed {
            label.opacity(Self.pressedOpacity)
        } else {
            label
        }
    }
}
