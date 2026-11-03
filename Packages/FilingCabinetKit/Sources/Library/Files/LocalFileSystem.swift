import Foundation

/// The real disk, through a private `FileManager` per call (never `.default`, never shared state).
package struct LocalFileSystem: FileSystem {
    package init() {}

    package func createDirectory(at url: URL) throws {
        try FileManager().createDirectory(at: url, withIntermediateDirectories: true)
    }

    package func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    package func removeItem(at url: URL) throws {
        try FileManager().removeItem(at: url)
    }

    package func contentsOfDirectory(at url: URL) throws -> [URL] {
        try FileManager().contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }

    package func fileExists(at url: URL) -> Bool {
        FileManager().fileExists(atPath: url.path(percentEncoded: false))
    }
}
