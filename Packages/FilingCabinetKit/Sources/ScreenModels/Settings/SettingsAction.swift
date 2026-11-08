/// What the screen does after a Settings change it cannot make itself.
package enum SettingsAction: Equatable {
    /// iOS decides: send the person to iPhone Settings.
    case openSystemSettings
}
