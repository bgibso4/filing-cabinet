import SwiftUI

/// A symbol in a filled circle above a sheet's or screen's title (the camera-off sheet, the failure screen, the
/// welcome's notifications screen). The symbol follows Dynamic Type and the circle grows with it. Decorative: the title
/// says what it means.
struct SymbolWell<Fill: ShapeStyle>: View {
    let systemName: String
    let font: Font
    let foreground: Color
    let fill: Fill
    /// The mock's diameter at default sizes.
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(font)
            .foregroundStyle(foreground)
            .padding(Tokens.Spacing.s3)
            .frame(minWidth: size, minHeight: size)
            .background(fill, in: .circle)
            .accessibilityHidden(true)
    }
}
