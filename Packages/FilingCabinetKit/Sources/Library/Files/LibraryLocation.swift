import Core
import Foundation

/// Where the library lives on disk: the store and originals under `root`, thumbnails under `caches`
/// (requirements 04 · Storage). Nothing is excluded from the device backup.
public struct LibraryLocation: Sendable {
    package let root: URL
    package let caches: URL

    public init(root: URL, caches: URL) {
        self.root = root
        self.caches = caches
    }

    /// The SwiftData store file.
    public var storeURL: URL { root.appending(path: "Library.store") }

    /// `root/Originals/<uuid>/`: the scan's HEIC pages.
    package func originals(for id: ScanID) -> URL {
        root.appending(path: "Originals", directoryHint: .isDirectory)
            .appending(path: id.uuid.uuidString, directoryHint: .isDirectory)
    }

    /// `caches/Thumbnails/<uuid>/`: the scan's small JPEG pages, rebuildable from the originals.
    package func thumbnails(for id: ScanID) -> URL {
        caches.appending(path: "Thumbnails", directoryHint: .isDirectory)
            .appending(path: id.uuid.uuidString, directoryHint: .isDirectory)
    }

    /// Application Support and Caches in the app's container.
    public static func standard() throws -> Self {
        let files = FileManager()
        let support = try files.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let caches = try files.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return Self(root: support, caches: caches)
    }
}
