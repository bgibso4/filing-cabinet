import os

/// The module's one logger and signposter. Titles and file names are private; page images are never logged.
enum LibraryLog {
    static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "Library")
    static let signposter = OSSignposter(subsystem: "com.cadre.filingcabinet", category: "Library")
}
