import CoreGraphics

/// A unit-mass spring that animates the viewer's Details progress (0 closed, 1 open). It is stepped by hand so a
/// grab mid-motion starts from the real position and velocity, and a new target keeps both.
package struct DetailsSpring: Sendable, Equatable {
    /// The mock's values (decision M3).
    package static let stiffness: CGFloat = 170
    package static let damping: CGFloat = 24

    /// The longest time one step integrates, so a stalled frame cannot overshoot wildly.
    private static let maxStep = 1.0 / 30
    private static let restDistance: CGFloat = 0.001
    private static let restSpeed: CGFloat = 0.01

    package var position: CGFloat
    package var velocity: CGFloat
    package var target: CGFloat

    package init(position: CGFloat, velocity: CGFloat, target: CGFloat) {
        self.position = position
        self.velocity = velocity
        self.target = target
    }

    /// Within a thousandth of the target and slower than 0.01 per second. A settled spring sits exactly on it.
    package var isSettled: Bool {
        abs(position - target) < Self.restDistance && abs(velocity) < Self.restSpeed
    }

    /// Semi-implicit Euler: velocity first, then position. Snaps to the target once settled.
    package mutating func step(by seconds: Double) {
        let delta = CGFloat(min(seconds, Self.maxStep))
        velocity += (-Self.stiffness * (position - target) - Self.damping * velocity) * delta
        position += velocity * delta
        if isSettled {
            position = target
            velocity = 0
        }
    }
}
