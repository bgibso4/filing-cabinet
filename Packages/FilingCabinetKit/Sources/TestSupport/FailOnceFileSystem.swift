import Foundation
import Library
import Synchronization

/// Wraps another file system and fails the first `write` with ENOSPC, then passes everything through.
/// The app uses it for `-FailSave`.
package struct FailOnceFileSystem: FileSystem {
    /// Shared across copies, so the one failure is spent once whoever holds the value.
    private final class State: Sendable {
        let hasFailed = Mutex(false)
    }

    private let base: any FileSystem
    private let state = State()

    package init(_ base: any FileSystem) {
        self.base = base
    }

    package func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
    }

    package func write(_ data: Data, to url: URL) throws {
        let failNow = state.hasFailed.withLock { hasFailed in
            defer { hasFailed = true }
            return !hasFailed
        }
        if failNow { throw POSIXError(.ENOSPC) }
        try base.write(data, to: url)
    }

    package func removeItem(at url: URL) throws {
        try base.removeItem(at: url)
    }

    package func contentsOfDirectory(at url: URL) throws -> [URL] {
        try base.contentsOfDirectory(at: url)
    }

    package func fileExists(at url: URL) -> Bool {
        base.fileExists(at: url)
    }
}
