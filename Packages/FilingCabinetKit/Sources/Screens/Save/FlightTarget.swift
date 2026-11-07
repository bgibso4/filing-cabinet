import ScreenModels
import SwiftUI

extension EnvironmentValues {
    /// Where the page in flight is landing, when that is on the screen in front of the user.
    @Entry var flightDestination: FlightDestination?
}

extension View {
    /// Marks this view as a place the saved page can land. While a flight is heading here, its frame in `.global`
    /// coordinates reaches the root through `FlightTargetFrameKey`; nil if it is scrolled out of its scroll view.
    func flightTarget(_ destination: FlightDestination) -> some View {
        modifier(FlightTarget(destination: destination))
    }
}

/// The frame of the current flight's destination. Only one view ever publishes it.
struct FlightTargetFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

private struct FlightTarget: ViewModifier {
    let destination: FlightDestination

    @Environment(\.flightDestination) private var flightDestination

    /// Measures only during its own flight, so a grid's tiles cost nothing while scrolling.
    func body(content: Content) -> some View {
        content.background {
            if flightDestination == destination {
                GeometryReader { proxy in
                    Color.clear.preference(key: FlightTargetFrameKey.self, value: visibleFrame(proxy))
                }
            }
        }
    }

    private func visibleFrame(_ proxy: GeometryProxy) -> CGRect? {
        let frame = proxy.frame(in: .global)
        guard let scrollBounds = proxy.bounds(of: .scrollView) else { return frame }
        // `bounds(of:)` answers in this view's own coordinates, which start at its top left.
        return FlightStyle.landingFrame(frame, visibleIn: scrollBounds.offsetBy(dx: frame.minX, dy: frame.minY))
    }
}
