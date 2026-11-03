import Core
import CoreGraphics

/// Full-size page images for the viewer.
package protocol PageImageProviding: Sendable {
    /// The page if it is already in memory; never touches the disk.
    func cachedPage(for id: ScanID, index: Int) -> CGImage?
    /// The page decoded at full size; nil if unavailable.
    func page(for id: ScanID, index: Int) async -> CGImage?
}
