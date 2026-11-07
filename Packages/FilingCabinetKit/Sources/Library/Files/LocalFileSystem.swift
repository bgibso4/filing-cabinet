import Foundation

/// The real disk, through a private `FileManager` per call (never `.default`, never shared state).
public struct LocalFileSystem: FileSystem {
    public init() {}

    public func createDirectory(at url: URL) throws {
        try FileManager().createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    public func removeItem(at url: URL) throws {
        try FileManager().removeItem(at: url)
    }

    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        try FileManager().contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager().fileExists(atPath: url.path(percentEncoded: false))
    }
}
