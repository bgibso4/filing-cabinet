import Core
import CoreGraphics
import Foundation

/// A scan's page files: HEIC originals (`page-N.heic`) and ~400 px JPEG thumbnails (`page-N.jpg`).
package struct PageFileStore: Sendable {
    /// M12: originals are HEIC at 0.8.
    private static let originalQuality = 0.8
    /// M12: thumbnails are 400 px on the long edge.
    private static let thumbnailMaxPixel = 400

    private let location: LibraryLocation
    private let fileSystem: any FileSystem

    package init(location: LibraryLocation, fileSystem: any FileSystem) {
        self.location = location
        self.fileSystem = fileSystem
    }

    /// Writes every page and returns the originals' file names in page order. All or nothing: on any
    /// failure both of the scan's folders are removed before throwing.
    @concurrent
    package func write(_ pages: [CGImage], for id: ScanID) async throws(LibraryError) -> [String] {
        let originals = location.originals(for: id)
        let thumbnails = location.thumbnails(for: id)
        do {
            try fileSystem.createDirectory(at: originals)
            try fileSystem.createDirectory(at: thumbnails)
            var names: [String] = []
            for (index, page) in pages.enumerated() {
                let stem = "page-\(index + 1)"
                let original = try ImageCoding.heic(page, quality: Self.originalQuality)
                try fileSystem.write(original, to: originals.appending(path: "\(stem).heic"))
                let thumbnail = try ImageCoding.jpegThumbnail(page, maxPixel: Self.thumbnailMaxPixel)
                try fileSystem.write(thumbnail, to: thumbnails.appending(path: "\(stem).jpg"))
                names.append("\(stem).heic")
            }
            return names
        } catch {
            let failure = LibraryError(error)
            LibraryLog.logger.error(
                "Writing \(pages.count) pages failed (\(String(describing: failure))): \(error.localizedDescription, privacy: .private)"
            )
            removeFolders(of: id)
            throw failure
        }
    }

    /// Removes the scan's originals and thumbnails. Missing folders are fine.
    @concurrent
    package func remove(_ id: ScanID) async {
        removeFolders(of: id)
    }

    /// Every scan that has an originals folder, whatever the store says (for orphan cleanup).
    @concurrent
    package func storedScanIDs() async -> [ScanID] {
        let folder = location.root.appending(path: "Originals", directoryHint: .isDirectory)
        guard fileSystem.fileExists(at: folder) else { return [] }
        do {
            return try fileSystem.contentsOfDirectory(at: folder)
                .compactMap { UUID(uuidString: $0.lastPathComponent) }
                .map(ScanID.init(uuid:))
        } catch {
            LibraryLog.logger.error("Listing originals failed: \(error.localizedDescription, privacy: .private)")
            return []
        }
    }

    private func removeFolders(of id: ScanID) {
        for folder in [location.originals(for: id), location.thumbnails(for: id)]
        where fileSystem.fileExists(at: folder) {
            do {
                try fileSystem.removeItem(at: folder)
            } catch {
                LibraryLog.logger.error(
                    "Removing \(folder.lastPathComponent, privacy: .private) failed: \(error.localizedDescription, privacy: .private)"
                )
            }
        }
    }
}
