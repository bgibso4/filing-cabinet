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

    /// Settled shut: Details can be let go.
    package var isClosed: Bool {
        isSettled && position == 0
    }

    /// A finger has it: it stays exactly at `position`, with no velocity, until released.
    package mutating func hold(at position: CGFloat) {
        self.position = position
        velocity = 0
        target = position
    }

    /// Let go at `velocity` (progress per second, positive toward open): a flick or the halfway point decides where it
    /// settles, and the motion carries on from the finger's speed.
    package mutating func release(velocity: CGFloat) {
        self.velocity = velocity
        target = DetailsMotion.target(progress: position, velocity: velocity)
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
