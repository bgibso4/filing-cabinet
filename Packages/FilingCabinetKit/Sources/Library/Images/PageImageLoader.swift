import Core
import CoreGraphics
import Foundation
import ImageIO

/// Decodes a page's original at full size. Only the viewer uses it; it keeps the 3 most recent pages.
public struct PageImageLoader: PageImageProviding {
    private static let memoryCapacity = 3

    private let location: LibraryLocation
    private let fileSystem: any FileSystem
    private let cache = ImageCache(capacity: memoryCapacity)

    public init(location: LibraryLocation, fileSystem: any FileSystem) {
        self.location = location
        self.fileSystem = fileSystem
    }

    public func cachedPage(for id: ScanID, index: Int) -> CGImage? {
        cache.image(for: .init(id: id, page: index))
    }

    @concurrent
    public func page(for id: ScanID, index: Int) async -> CGImage? {
        let key = ImageCache.Key(id: id, page: index)
        if let hit = cache.image(for: key) { return hit }
        let url = location.originals(for: id).appending(path: "page-\(index + 1).heic")
        guard
            fileSystem.fileExists(at: url),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        cache.insert(image, for: key)
        return image
    }
}
