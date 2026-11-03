import Foundation

/// The file operations the library needs: the seam tests use to fail a write.
public protocol FileSystem: Sendable {
    /// Creates the directory and any missing parents; succeeds if it already exists.
    func createDirectory(at url: URL) throws
    /// Writes atomically, replacing any existing file.
    func write(_ data: Data, to url: URL) throws
    func removeItem(at url: URL) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func fileExists(at url: URL) -> Bool
}
