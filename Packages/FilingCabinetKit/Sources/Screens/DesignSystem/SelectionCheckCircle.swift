import SwiftUI

/// The tick on a tile's thumbnail while selecting (Trash.dc.html line 53), in Trash and the grids (#68): a white-ringed
/// circle, filled with a tick once the scan is selected. The tile's traits tell VoiceOver, so the circle is hidden from
/// it.
struct SelectionCheckCircle: View {
    let isOn: Bool

    // Trash.dc.html line 53: a 24 pt circle with a 1.5 pt white ring and a 12 pt tick, 6 pt in from the corner.
    private static let diameter: CGFloat = 24
    private static let ringWidth: CGFloat = 1.5
    private static let tickSize: CGFloat = 12
    private static let inset: CGFloat = 6
    // Trash.dc.html line 229: an unticked circle is white at 55%.
    private static let offOpacity = 0.55

    var body: some View {
        Circle()
            .fill(isOn ? Tokens.Color.textPrimary : Color.white.opacity(Self.offOpacity))
            .frame(width: Self.diameter, height: Self.diameter)
            .overlay {
                Circle().strokeBorder(.white, lineWidth: Self.ringWidth)
                if isOn {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.bold)
                        .frame(width: Self.tickSize, height: Self.tickSize)
                        .foregroundStyle(Tokens.Color.bgGrouped)
                }
            }
            .padding(Self.inset)
            .accessibilityHidden(true)
    }
}

extension View {
    /// A tile's thumbnail in select mode: faded once ticked, with the check circle in its bottom trailing corner.
    /// Apply it after clipping the thumbnail, so the circle isn't clipped.
    func selectionMark(isSelecting: Bool, isSelected: Bool) -> some View {
        modifier(SelectionMark(isSelecting: isSelecting, isSelected: isSelected))
    }
}

private struct SelectionMark: ViewModifier {
    let isSelecting: Bool
    let isSelected: Bool

    // Trash.dc.html line 49: a ticked scan's image fades to 75%.
    private static let selectedImageOpacity = 0.75

    func body(content: Content) -> some View {
        content
            .opacity(isSelected ? Self.selectedImageOpacity : 1)
            .overlay(alignment: .bottomTrailing) {
                if isSelecting { SelectionCheckCircle(isOn: isSelected) }
            }
    }
}
