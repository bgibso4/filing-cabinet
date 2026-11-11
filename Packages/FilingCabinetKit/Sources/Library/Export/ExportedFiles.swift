import Foundation
import Synchronization

/// The PDFs one screen exported (M20): a viewer, or a grid's selection. Ending its share or file export removes only
/// these, so another screen's export still in use is left alone. Launch clears the rest with `ScanExport.removeAll()`.
package final class ExportedFiles: Sendable {
    private let export: ScanExport
    private let made = Mutex<[URL]>([])

    package init(export: ScanExport) {
        self.export = export
    }

    /// Writes the scan's PDF, as `ScanExport.pdf(for:named:)` does, and keeps it for `removeAll()`.
    package func pdf(for scan: ScanSummary, named name: String) async throws(LibraryError) -> URL {
        let url = try await export.pdf(for: scan, named: name)
        made.withLock { $0.append(url) }
        return url
    }

    /// Removes every PDF this screen made, each with its own export folder.
    package func removeAll() {
        let urls = made.withLock { urls in
            let all = urls
            urls = []
            return all
        }
        for url in urls { export.remove(url) }
    }
}
