import SwiftUI

/// Draws `content` at its progress through a repeating cycle of `period` seconds, from 0 up to 1, every frame,
/// starting at 0 when it appears. Snapshot tests hold every cycle still with `stillMotionProgress`.
struct LoopingProgress<Content: View>: View {
    let period: TimeInterval
    @ViewBuilder let content: (Double) -> Content

    @State private var start = Date.now
    @Environment(\.stillMotionProgress) private var stillProgress

    var body: some View {
        if let stillProgress {
            content(stillProgress)
        } else {
            TimelineView(.animation) { context in
                content(context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: period) / period)
            }
        }
    }
}

extension EnvironmentValues {
    /// Snapshot tests only: every looping motion (the shimmer, the sweep) is drawn still, this far through its cycle,
    /// so a snapshot doesn't depend on when it was taken.
    @Entry public var stillMotionProgress: Double?
}
