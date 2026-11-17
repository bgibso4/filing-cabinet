import Core
import Foundation
import LocalAuthentication
import os

/// The phone's owner check: Face ID, then iOS's own passcode fallback. In the app target, the only one that imports
/// LocalAuthentication. Nonisolated and stateless: each call makes its own `LAContext`, which is single-use.
nonisolated struct SystemAuthenticator: DeviceAuthenticating {
    private static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "App")

    func availability() -> AuthenticationAvailability {
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) { return .biometrics }
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) { return .passcodeOnly }
        return .none
    }

    func authenticate(reason: String) async -> AuthenticationResult {
        // Held until the answer is in: a context let go mid-check is invalidated, which cancels the prompt.
        let context = LAContext()
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return .success
        } catch let error as LAError where [.userCancel, .systemCancel, .appCancel].contains(error.code) {
            return .cancelled
        } catch {
            // The code is a fixed enum value, not personal data.
            Self.logger.error("The owner check failed: \((error as NSError).code, privacy: .public)")
            return .failed
        }
    }
}
