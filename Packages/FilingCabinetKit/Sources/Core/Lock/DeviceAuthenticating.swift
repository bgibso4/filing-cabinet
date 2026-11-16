/// Asks iOS whether the person holding the phone is its owner.
public protocol DeviceAuthenticating: Sendable {
    func availability() -> AuthenticationAvailability
    /// Face ID first; the passcode when Face ID isn't working. `reason` is the line iOS shows.
    func authenticate(reason: String) async -> AuthenticationResult
}

/// What the phone can check the owner with.
public enum AuthenticationAvailability: Sendable, Equatable { case biometrics, passcodeOnly, none }

/// How a check ended.
public enum AuthenticationResult: Sendable, Equatable { case success, cancelled, failed }
