import Foundation

/// The Photos seam (M11): adds pages to Photos with add-only access, asking iOS the first time. The system's in the
/// app, a scripted one in tests and under `-Photos`, so a UI test never sees the system prompt.
public protocol PhotoSaving: Sendable {
    /// Adds each page file as its own photo.
    func save(pages: [URL]) async throws(PhotoSaveError)
}
