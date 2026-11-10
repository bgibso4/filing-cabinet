import Core
import Foundation
import Synchronization

/// Photos with a scripted answer: it saves, or throws `failing`. Remembers every save's pages, in order.
public final class FakePhotoSaving: PhotoSaving {
    private let failing: PhotoSaveError?
    private let saves = Mutex<[[URL]]>([])

    public init(failing: PhotoSaveError? = nil) {
        self.failing = failing
    }

    /// `-Photos`: authorized saves, denied throws `.denied`.
    public convenience init(_ authorization: PhotosAuthorization) {
        self.init(failing: authorization == .denied ? .denied : nil)
    }

    package var saved: [[URL]] { saves.withLock { $0 } }

    public func save(pages: [URL]) async throws(PhotoSaveError) {
        if let failing { throw failing }
        saves.withLock { $0.append(pages) }
    }
}
