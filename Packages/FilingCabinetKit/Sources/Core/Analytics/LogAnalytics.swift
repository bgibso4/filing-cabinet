import os

/// Stand-in provider: writes each event to the unified log.
public struct LogAnalytics: Analytics {
    private static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "Analytics")

    public init() {}

    public func send(_ event: AnalyticsEvent) {
        Self.logger.info(
            "analytics \(event.name, privacy: .public) \(String(describing: event.payload), privacy: .public)")
    }
}
