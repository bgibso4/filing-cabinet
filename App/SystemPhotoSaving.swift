import Core
import Foundation
import Photos
import os

/// The system's Photos with add-only access (M11): iOS asks the first time, and a denied or restricted answer stays
/// until the person changes it in Settings. In the app target, which owns the system's shared library. Nonisolated:
/// Photos runs the change block on its own queue.
nonisolated struct SystemPhotoSaving: PhotoSaving {
    private static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "App")

    func save(pages: [URL]) async throws(PhotoSaveError) {
        switch await PHPhotoLibrary.requestAuthorization(for: .addOnly) {
        case .authorized, .limited: break
        case .denied, .restricted, .notDetermined: throw .denied
        @unknown default: throw .denied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                // Each page from its original HEIC, as its own photo.
                for page in pages {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: page, options: nil)
                }
            }
        } catch {
            Self.logger.error(
                "Saving \(pages.count, privacy: .public) pages to Photos failed: \(error.localizedDescription, privacy: .private)"
            )
            throw .failed
        }
    }
}
