import Core
import TelemetryDeck

/// Release builds' provider: each event becomes a TelemetryDeck signal, its name the signal type and its payload the
/// signal's parameters. Make one per process: `init` sets TelemetryDeck up.
nonisolated struct TelemetryDeckAnalytics: Analytics {
    init(appID: String) {
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
    }

    func send(_ event: AnalyticsEvent) {
        TelemetryDeck.signal(event.name, parameters: event.signalParameters)
    }
}
