import Foundation
import Synchronization
import os

/// Records the app's memory at a stage of a scan, to the log and to a file in Caches, in debug builds on iOS only
/// (#50). A phone's camera can't be used while Instruments is attached, so the app keeps its own readings and the file
/// is copied off afterwards. Lines hold a time, a stage, a page count and numbers: never a title, text or an image.
public enum MemoryLog {
    package static let fileName = "memory-readings.txt"

    private static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "Core")
    private static let bytesPerMegabyte: UInt64 = 1_048_576
    /// One append at a time, so two stages recorded at once never share a line.
    private static let writing = Mutex(())

    /// Does nothing in a Release build and on the Mac, where the Fast tests would write into the developer's Caches.
    public static func record(_ stage: MemoryStage, pages: Int? = nil) {
        #if DEBUG && os(iOS)
            let line = line(stage, pages: pages, reading: .current(), at: .now)
            logger.notice("Memory: \(line, privacy: .public)")
            do {
                try append(line, to: URL.cachesDirectory.appending(path: fileName))
            } catch {
                logger.error("Memory reading not written: \(error.localizedDescription, privacy: .public)")
            }
        #endif
    }

    package static func line(_ stage: MemoryStage, pages: Int?, reading: MemoryReading?, at date: Date) -> String {
        var fields = [date.formatted(.iso8601), stage.rawValue]
        if let pages { fields.append("pages \(pages)") }
        if let reading {
            fields.append("now \(megabytes(reading.now)) MB")
            fields.append("peak \(megabytes(reading.peak)) MB")
            if let left = reading.left { fields.append("left \(megabytes(left)) MB") }
        } else {
            fields.append("unavailable")
        }
        return fields.joined(separator: "  ")
    }

    /// Adds the line to the end of the file, creating the file and its folder when missing.
    package static func append(_ line: String, to file: URL) throws {
        try writing.withLock { _ in
            let files = FileManager.default
            try files.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !files.fileExists(atPath: file.path) { try Data().write(to: file) }
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }  // Nothing to do about a failed close: the line is already written.
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
        }
    }

    private static func megabytes(_ bytes: UInt64) -> UInt64 {
        (bytes + bytesPerMegabyte / 2) / bytesPerMegabyte
    }
}
