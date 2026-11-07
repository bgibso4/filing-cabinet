import os

/// The module's one logger and signposter.
enum ScreensLog {
    static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "Screens")
    static let signposter = OSSignposter(subsystem: "com.cadre.filingcabinet", category: "Screens")
}
