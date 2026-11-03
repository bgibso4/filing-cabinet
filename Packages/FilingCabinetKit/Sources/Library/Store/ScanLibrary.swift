import Core

/// The saved scans as the screens see them. `ScanStore` is the real one; `FakeLibrary` stands in for tests.
@MainActor
package protocol ScanLibrary: AnyObject {
    /// Every scan, newest `scannedAt` first.
    var scans: [ScanSummary] { get }

    /// Saves the draft's files and record, all or nothing. Throws `.diskFull` or `.writeFailed`.
    func save(_ draft: ScanDraft) async throws(LibraryError)

    /// Sets the scan's search text once reading finishes. A failure is logged; the scan stays saved.
    func updateSearchText(_ text: String, for id: ScanID)
}
