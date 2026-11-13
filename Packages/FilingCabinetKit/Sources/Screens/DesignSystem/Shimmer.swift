import SwiftUI

/// A placeholder that fills its frame with `base`, a lighter band passing across it left to right while something
/// loads (the loading mock, option B: claude.ai/artifact/SZ5Ntg5vThvnYN3KAgv14Q, `.bar`). Once loading ends
/// (`isActive` false), and under Reduce Motion, it is plain `base` and draws no more frames.
struct Shimmer: View {
    let base: Color
    let highlight: Color
    let isActive: Bool

    // SZ5N `.bar`: one pass every 1.3 s, linear.
    private static let period: TimeInterval = 1.3
    // SZ5N `.bar`: the gradient is three times the bar's width, the band peaking at its middle (35%, 50%, 65%) and
    // moving from showing the gradient's last third to its first.
    private static let gradientWidths: Double = 3
    private static let bandStart = 0.35
    private static let bandPeak = 0.5
    private static let bandEnd = 0.65

    @Environment(\.reducesMotion) private var reducesMotion

    var body: some View {
        if reducesMotion || !isActive {
            Rectangle().fill(base)
        } else {
            LoopingProgress(period: Self.period) { progress in
                Rectangle().fill(gradient(at: progress))
            }
        }
    }

    /// The gradient, in units of the bar's width, starts 2 widths left of the bar and ends level with it.
    private func gradient(at progress: Double) -> LinearGradient {
        let start = -(Self.gradientWidths - 1) * (1 - progress)
        return LinearGradient(
            stops: [
                .init(color: base, location: Self.bandStart),
                .init(color: highlight, location: Self.bandPeak),
                .init(color: base, location: Self.bandEnd),
            ],
            startPoint: UnitPoint(x: start, y: 0.5),
            endPoint: UnitPoint(x: start + Self.gradientWidths, y: 0.5))
    }
}
