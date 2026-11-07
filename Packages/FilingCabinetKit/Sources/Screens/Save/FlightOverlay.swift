import Core
import ScreenModels
import SwiftUI

/// The save moment (A3): page 1 appears where review showed it, shrinks into its badge or tile and fades there, or
/// fades where it is. It sits over the root, seen by nobody but the eye: no touches, no VoiceOver.
struct FlightOverlay: View {
    let flow: ScanFlowModel
    /// The destination's frame, if it has published one (see `flightTarget`).
    let targetFrame: CGRect?
    /// `-ReduceMotion`.
    let forcesReduceMotion: Bool

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// Set from `targetFrame`, because the flight's task only sees the props it started with.
    @State private var latestTargetFrame: CGRect?
    @State private var screen = CGRect.zero
    /// Nil until the page leaves `flight.from`.
    @State private var landing: Landing?
    @State private var opacity = 1.0

    private struct Landing {
        let frame: CGRect
        let cornerRadius: CGFloat
    }

    var body: some View {
        GeometryReader { _ in
            if let flight = flow.flight { page(flight) }
        }
        // Measured inside `ignoresSafeArea`: outside it, this would report the safe area, not the screen.
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: {
            screen = $0
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: targetFrame, initial: true) { _, frame in
            latestTargetFrame = frame
        }
        .task(id: flow.flight) {
            if let flight = flow.flight { await run(flight) }
        }
    }

    /// Filled from the top like a grid thumbnail, so it arrives as the tile shows it.
    private func page(_ flight: ScanFlowModel.Flight) -> some View {
        let frame = landing?.frame ?? flight.from
        let cornerRadius: CGFloat = landing?.cornerRadius ?? 0
        return Color.clear
            .overlay(alignment: .top) {
                Image(decorative: flight.page, scale: 1).resizable().scaledToFill()
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX - screen.minX, y: frame.midY - screen.minY)
            .opacity(opacity)
            .accessibilityIdentifier(AccessibilityID.Save.flight)
    }

    private func run(_ flight: ScanFlowModel.Flight) async {
        await pause(FlightStyle.destinationWait)
        let target = FlightStyle.landingFrame(latestTargetFrame, visibleIn: screen)
        let style = FlightStyle.choose(
            reduceMotion: systemReduceMotion || forcesReduceMotion, hasDestination: target != nil)
        if style == .fly, let target {
            withAnimation(.spring(duration: FlightStyle.flyDuration)) {
                landing = Landing(frame: target, cornerRadius: cornerRadius(at: target, for: flight.destination))
            }
            await pause(FlightStyle.flyDuration)
            await fadeOut(over: FlightStyle.landingFadeDuration)
        } else {
            await fadeOut(over: FlightStyle.fadeDuration)
        }
        finish()
    }

    private func fadeOut(over duration: TimeInterval) async {
        withAnimation(.easeOut(duration: duration)) { opacity = 0 }
        await pause(duration)
    }

    /// Animated, so the count on the landing row rolls up (`HomeCount`).
    private func finish() {
        guard !Task.isCancelled else { return }
        let announcement = withAnimation { flow.flightFinished() }
        landing = nil
        opacity = 1
        if let announcement { AccessibilityNotification.Announcement(announcement).post() }
    }

    private func cornerRadius(at frame: CGRect, for destination: FlightDestination) -> CGFloat {
        switch destination {
        case .badge: frame.width / 2
        case .tile: Tokens.Radius.nested
        }
    }

    /// Sleeps; if cancelled it returns early and `finish` does nothing.
    private func pause(_ duration: TimeInterval) async {
        // try?: the sleep only throws when cancelled, and `finish` checks for that.
        try? await Task.sleep(for: .seconds(duration))
    }
}
