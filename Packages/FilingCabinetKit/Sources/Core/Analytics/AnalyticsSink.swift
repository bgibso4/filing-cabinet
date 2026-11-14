/// Where analytics events go: the unified log, or TelemetryDeck.
public enum AnalyticsSink: Equatable {
    case log
    case telemetryDeck(appID: String)

    /// The log in Debug builds, or without a usable app ID; TelemetryDeck otherwise.
    public static func choose(isDebugBuild: Bool, appID: String?) -> Self {
        guard !isDebugBuild, let id = appID?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return .log
        }
        return .telemetryDeck(appID: id)
    }
}
