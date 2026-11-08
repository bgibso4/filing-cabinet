import os

/// The module's one logger. Log timings and counts, never recognized text.
enum UnderstandingLog {
    static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "Understanding")
    static let signposter = OSSignposter(logger: logger)
}
