import os

/// The module's one logger. File names are private; page images are never logged.
enum LibraryLog {
    static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "Library")
}
