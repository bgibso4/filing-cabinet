import CoreGraphics
import Dispatch
import Synchronization

/// Runs image decodes one at a time on a serial queue of its own, never on Swift's cooperative pool, and lets callers
/// asking for the same page while it decodes share that one decode.
///
/// A decode blocks the thread it runs on, and ImageIO's HEIC decoder can need another thread before it finishes. On a
/// machine with few cores and no hardware HEVC (CI's virtual Mac), three page decodes blocking cooperative threads used
/// up the pool, the decoder never got its thread, and the viewer deadlocked.
final class ImageDecodeQueue: Sendable {
    private let queue: DispatchQueue
    private let inFlight = Mutex<[ImageCache.Key: Task<CGImage?, Never>]>([:])

    init(label: String) {
        queue = DispatchQueue(label: label, qos: .userInitiated)
    }

    /// The result of `decode` for `key`: the running decode's when there is one, otherwise a new one queued behind any
    /// others. `decode` should fill the caller's cache, so a request after it finishes is a cache hit.
    func image(for key: ImageCache.Key, decode: @escaping @Sendable () -> CGImage?) async -> CGImage? {
        let decoding = inFlight.withLock { inFlight in
            if let running = inFlight[key] { return running }
            let task = Task { [queue] in
                await withCheckedContinuation { continuation in
                    queue.async { continuation.resume(returning: decode()) }
                }
            }
            inFlight[key] = task
            return task
        }
        let image = await decoding.value
        inFlight.withLock { inFlight in
            // A later decode of the same page may have started since; leave it.
            if inFlight[key] == decoding { inFlight[key] = nil }
        }
        return image
    }
}
