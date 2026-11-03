import Core
import CoreGraphics

/// Small page images for grids. Views render `cachedThumbnail` first, then await `thumbnail`.
package protocol ThumbnailProviding: Sendable {
    /// The thumbnail if it is already in memory; never touches the disk.
    func cachedThumbnail(for id: ScanID, page: Int) -> CGImage?
    /// The thumbnail, loaded from the cache folder (or rebuilt from the original); nil if unavailable.
    func thumbnail(for id: ScanID, page: Int) async -> CGImage?
}
