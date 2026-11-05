import Core
import CoreGraphics
import Foundation

/// What the camera hands to review: the pages (M19) and where the scan came from.
package struct ReviewInput: Equatable {
    package let pages: [CGImage]
    /// The collection the scan was started from (a grid's Scan), if any.
    package let preselected: BuiltInCollection?
    package let scannedAt: Date
    package let source: ScanSource

    package init(pages: [CGImage], preselected: BuiltInCollection?, scannedAt: Date, source: ScanSource) {
        self.pages = pages
        self.preselected = preselected
        self.scannedAt = scannedAt
        self.source = source
    }

    /// The same scan with a rescan's pages.
    func replacingPages(_ pages: [CGImage]) -> Self {
        Self(pages: pages, preselected: preselected, scannedAt: scannedAt, source: source)
    }
}
