import SwiftUI

/// The round neutral badge with a view's white symbol (Recent, All Scans).
struct ViewBadge: View {
    let symbol: String
    let diameter: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        Circle()
            .fill(Tokens.Color.badgeNeutral)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: symbolSize, height: symbolSize)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
