import SwiftUI

extension EnvironmentValues {
    /// `-ReduceMotion` (Debug only): Reduce Motion's paths whatever the system setting, so UI tests can reach them,
    /// and snapshot tests. `accessibilityReduceMotion` can't be set from outside.
    @Entry public var forcesReduceMotion = false

    /// What a screen with a Reduce Motion path reads: the system setting, or the launch flag.
    var reducesMotion: Bool { accessibilityReduceMotion || forcesReduceMotion }
}
