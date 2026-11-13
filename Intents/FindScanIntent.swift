import AppIntents
import Core

/// Opens the app on Search with the text in the field and its results showing (Plan 6 §7). Siri can't carry free text
/// in a phrase, so "Find a scan in Filing Cabinet" asks for it.
struct FindScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Find a scan"
    // periphery:ignore - read by the system's App Intents metadata, not by code
    static let description = IntentDescription("Opens Search in Filing Cabinet with this text.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Text", requestValueDialog: "What are you looking for?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Find scans matching \(\.$text)")
    }

    @Dependency private var requests: ExternalRequests

    @MainActor
    func perform() async throws -> some IntentResult {
        requests.send(.search(text))
        return .result()
    }
}
