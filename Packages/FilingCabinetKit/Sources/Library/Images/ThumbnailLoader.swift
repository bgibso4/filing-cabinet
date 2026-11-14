import Core
import CoreGraphics
import Foundation
import ImageIO

/// Loads ~400 px thumbnails. Never decodes a full-resolution original: a missing thumbnail is rebuilt
/// with `CGImageSourceCreateThumbnailAtIndex`, written back to the cache and returned.
public struct ThumbnailLoader: ThumbnailProviding {
    /// M12: thumbnails are 400 px on the long edge.
    private static let maxPixel = 400
    /// Bounded memory: the grid only needs what is near the screen.
    private static let memoryCapacity = 200

    private let location: LibraryLocation
    private let fileSystem: any FileSystem
    private let cache = ImageCache(capacity: memoryCapacity)
    private let decodes = ImageDecodeQueue(label: "com.cadre.filingcabinet.thumbnail-decode")

    public init(location: LibraryLocation, fileSystem: any FileSystem) {
        self.location = location
        self.fileSystem = fileSystem
    }

    public func cachedThumbnail(for id: ScanID, page: Int) -> CGImage? {
        cache.image(for: .init(id: id, page: page))
    }

    @concurrent
    public func thumbnail(for id: ScanID, page: Int) async -> CGImage? {
        let key = ImageCache.Key(id: id, page: page)
        if let hit = cache.image(for: key) { return hit }
        // A tile scrolled away before its turn isn't worth queueing.
        guard !Task.isCancelled else { return nil }
        return await decodes.image(for: key) { [cache] in
            cache.image(for: key)
        } decode: { [self] in
            load(page: page, for: id, key: key)
        }
    }

    /// Page 1's cached JPEG as stored, for Spotlight (M12): read off the main actor, never rebuilt. Nil when it isn't
    /// cached.
    @concurrent
    public func firstPageJPEG(for id: ScanID) async -> Data? {
        let url = cachedFile(page: 0, for: id)
        guard fileSystem.fileExists(at: url) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            LibraryLog.logger.error("Reading a thumbnail failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    /// `caches/Thumbnails/<uuid>/page-<n>.jpg`, `page` counted from 0.
    private func cachedFile(page: Int, for id: ScanID) -> URL {
        location.thumbnails(for: id).appending(path: "page-\(page + 1).jpg")
    }

    /// The cached JPEG, or the thumbnail rebuilt from the original; runs on the decode queue.
    private func load(page: Int, for id: ScanID, key: ImageCache.Key) -> CGImage? {
        let signposter = LibraryLog.signposter
        let state = signposter.beginInterval("Thumbnail decode")
        defer { signposter.endInterval("Thumbnail decode", state) }
        let stem = "page-\(page + 1)"
        let cached = cachedFile(page: page, for: id)
        let image = fileSystem.fileExists(at: cached) ? Self.decode(cached) : nil
        guard let loaded = image ?? rebuild(stem: stem, for: id) else { return nil }
        cache.insert(loaded, for: key)
        return loaded
    }

    private func rebuild(stem: String, for id: ScanID) -> CGImage? {
        let original = location.originals(for: id).appending(path: "\(stem).heic")
        guard fileSystem.fileExists(at: original), let image = Self.decode(original) else { return nil }
        do {
            let folder = location.thumbnails(for: id)
            try fileSystem.createDirectory(at: folder)
            try fileSystem.write(
                ImageCoding.jpegThumbnail(image, maxPixel: Self.maxPixel), to: folder.appending(path: "\(stem).jpg"))
        } catch {
            LibraryLog.logger.error("Rewriting a thumbnail failed: \(error.localizedDescription, privacy: .private)")
        }
        return image
    }

    /// Decodes at most `maxPixel` on the long edge, honouring the file's orientation.
    private static func decode(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
