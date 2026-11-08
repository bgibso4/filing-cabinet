import os

/// The module's one logger and signposter. Nonisolated: both are thread-safe, and the system adapters log off the main
/// actor.
nonisolated enum ScreensLog {
    static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "Screens")
    static let signposter = OSSignposter(subsystem: "com.cadre.filingcabinet", category: "Screens")
}
