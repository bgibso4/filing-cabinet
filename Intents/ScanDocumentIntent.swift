import AppIntents
import Core

/// Opens the app at the camera: the Scan control, its App Shortcut and Siri (Plan 6 §7). Compiled into the app and the
/// controls extension; `.foreground` runs `perform` in the app, where `ExternalRequests` is registered, and the root acts
/// on the request once launch and the welcome are done.
struct ScanDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a document"
    // periphery:ignore - read by the system's App Intents metadata, not by code
    static let description = IntentDescription("Opens the camera in Filing Cabinet.")
    static let supportedModes: IntentModes = .foreground

    @Dependency private var requests: ExternalRequests

    @MainActor
    func perform() async throws -> some IntentResult {
        requests.send(.scan)
        return .result()
    }
}
