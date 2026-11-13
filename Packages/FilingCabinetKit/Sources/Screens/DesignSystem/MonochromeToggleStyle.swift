import SwiftUI

/// The black-and-white switch (Settings2.dc.html lines 37 and 178-179): colour is only for collections and expiry, so
/// "on" is a primary-colour track with a surface-colour knob, which keeps the knob visible in dark mode where the system
/// switch's white knob vanishes on its light track. Only the switch is drawn; the label goes to VoiceOver, which reads
/// the system switch this stands for ("Switch button, on").
struct MonochromeToggleStyle: ToggleStyle {
    // Settings2.dc.html line 37: a 51 by 31 pt track, a 27 pt knob, 2 pt in from the track's edge.
    private static let trackWidth: CGFloat = 51
    private static let trackHeight: CGFloat = 31
    private static let knobInset: CGFloat = 2
    private static let knobSize: CGFloat = 27
    // 10-06 (Apple Intelligence not available): a switch that can't be used dims its track to about half and keeps
    // its knob, outlined in a one-pixel separator-coloured edge so it still reads on the light track.
    private static let disabledTrackOpacity = 0.5

    @Environment(\.reducesMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.displayScale) private var displayScale

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            track(isOn: configuration.isOn)
                // The tap target is 44 pt tall; the negative padding keeps the row laid out around the 31 pt track.
                .frame(minHeight: Tokens.Spacing.tapMin)
                .contentShape(.rect)
                .padding(.vertical, -(Tokens.Spacing.tapMin - Self.trackHeight) / 2)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .snappy, value: configuration.isOn)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }

    private func track(isOn: Bool) -> some View {
        Capsule()
            .fill(trackColor(isOn: isOn))
            .frame(width: Self.trackWidth, height: Self.trackHeight)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(isOn ? Tokens.Color.bgSurface : Tokens.Color.switchKnobOff)
                    .overlay {
                        if !isEnabled {
                            Circle().strokeBorder(Tokens.Color.separator, lineWidth: 1 / displayScale)
                        }
                    }
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .padding(Self.knobInset)
            }
    }

    /// Dimmed when the switch can't be used; the knob stays as it is (10-06).
    private func trackColor(isOn: Bool) -> Color {
        let color = isOn ? Tokens.Color.textPrimary : Tokens.Color.switchTrackOff
        return isEnabled ? color : color.opacity(Self.disabledTrackOpacity)
    }
}
