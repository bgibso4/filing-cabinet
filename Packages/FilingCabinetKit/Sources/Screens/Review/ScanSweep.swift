import SwiftUI

/// A soft scanner bar passing down the page while the model reads it (the loading mock, option B:
/// claude.ai/artifact/SZ5Ntg5vThvnYN3KAgv14Q, `.sweep`). It fills, and is clipped to, the page's own frame. Nothing
/// under Reduce Motion.
struct ScanSweep: View {
    // SZ5N `.sweep`: a 140 pt band, from just above the page to just below it every 1.9 s, eased in and out
    // (cubic-bezier(.45, 0, .55, 1)).
    private static let bandHeight: CGFloat = 140
    private static let period: TimeInterval = 1.9
    private static let easing = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.45, y: 0), endControlPoint: UnitPoint(x: 0.55, y: 1))
    // SZ5N `.sweep`: the band darkens towards its lower edge (7% at 78%, 28% at 99%) under a 1.5 pt line at 55%, 1 pt
    // up from the edge. Its colour is the mock's rgb(28, 28, 30) in both appearances, as the page is paper in both: the
    // mark-ground token.
    private static let band = Gradient(stops: [
        .init(color: .clear, location: 0),
        .init(color: Tokens.Color.markGround.opacity(0.07), location: 0.78),
        .init(color: Tokens.Color.markGround.opacity(0.28), location: 0.99),
        .init(color: .clear, location: 1),
    ])
    private static let lineHeight: CGFloat = 1.5
    private static let lineOpacity = 0.55
    private static let lineInset: CGFloat = 1

    @Environment(\.reducesMotion) private var reducesMotion

    var body: some View {
        if !reducesMotion {
            GeometryReader { proxy in
                LoopingProgress(period: Self.period) { progress in
                    bar.offset(y: top(at: progress, pageHeight: proxy.size.height))
                }
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var bar: some View {
        LinearGradient(gradient: Self.band, startPoint: .top, endPoint: .bottom)
            .frame(height: Self.bandHeight)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Tokens.Color.markGround.opacity(Self.lineOpacity))
                    .frame(height: Self.lineHeight)
                    .padding(.bottom, Self.lineInset)
            }
    }

    /// The band's top: one band height above the page at the start, at the page's bottom at the end.
    private func top(at progress: Double, pageHeight: CGFloat) -> CGFloat {
        -Self.bandHeight + (pageHeight + Self.bandHeight) * Self.easing.value(at: progress)
    }
}
