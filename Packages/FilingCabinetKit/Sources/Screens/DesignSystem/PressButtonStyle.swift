import SwiftUI

/// Home's rows and favourite cards while a finger is down (B18): the pressed fill behind them, as a system list row
/// highlights, quick in and quick out; a card also shrinks a little (not with Reduce Motion). The grids' tiles have no
/// press of their own to match (`.plain`).
struct PressButtonStyle<Highlight: Shape>: ButtonStyle {
    let highlight: Highlight
    /// 1 leaves the label unscaled: no scale effect at all, so a row renders exactly as it does unpressed.
    let pressedScale: CGFloat

    // B18 round 2 (Ben: the 97 % press "has no visible effect"). My call: 0.1 s each way. No motion tokens exist in
    // design/tokens.json.
    private static var press: Animation { .easeOut(duration: 0.1) }

    @Environment(\.reducesMotion) private var reduceMotion

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let lit = configuration.label
            .background {
                if isPressed { highlight.fill(Tokens.Color.bgPressed) }
            }
        if pressedScale == 1 || reduceMotion {
            lit.animation(Self.press, value: isPressed)
        } else {
            lit
                .scaleEffect(isPressed ? pressedScale : 1)
                .animation(Self.press, value: isPressed)
        }
    }
}

extension PressButtonStyle where Highlight == Rectangle {
    /// A row: the fill across the whole row, no scale. Its card clips the corners.
    static var row: Self { Self(highlight: Rectangle(), pressedScale: 1) }
}

extension PressButtonStyle where Highlight == RoundedRectangle {
    // B18 round 2 (Ben): "a slightly stronger scale on the favourite cards (~0.95)".
    private static var cardScale: CGFloat { 0.95 }

    /// A favourite card: the fill behind the card, its thumbnail's corners, and a slight shrink.
    static var card: Self {
        Self(highlight: RoundedRectangle(cornerRadius: Tokens.Radius.nested), pressedScale: cardScale)
    }
}
