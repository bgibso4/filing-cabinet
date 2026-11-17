/// Settings' Lock with Face ID row and the line under it.
package struct LockRow: Equatable {
    /// False only when the phone has no passcode and the wish is off: there is nothing to lock with.
    package let isEnabled: Bool
    /// The person's wish, so a paused lock still shows on.
    package let isOn: Bool
    package let subtitle: String
    package let footer: String
}
