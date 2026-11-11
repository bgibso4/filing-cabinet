import os

/// The module's one logger.
enum ScreenModelsLog {
    static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "ScreenModels")
    /// Intervals for a trace: "Search" wraps one matching pass. Never carries text.
    static let signposter = OSSignposter(subsystem: "com.cadre.filingcabinet", category: "ScreenModels")
}
