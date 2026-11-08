import CoreGraphics
import Dispatch
import Synchronization

/// Runs image decodes one at a time on a serial queue of its own, never on Swift's cooperative pool, and lets callers
/// asking for the same page while it decodes share that one decode.
///
/// A decode blocks the thread it runs on, and ImageIO's HEIC decoder can need another thread before it finishes. On a
/// machine with few cores and no hardware HEVC (CI's virtual Mac), three page decodes blocking cooperative threads used
/// up the pool, the decoder never got its thread, and the viewer deadlocked.
///
/// A queued decode that every caller has given up on (a fling through a grid) is skipped when its turn comes, so the
/// pages on screen don't wait behind ones nobody wants.
final class ImageDecodeQueue: Sendable {
    private struct Entry {
        let task: Task<CGImage?, Never>
        /// Callers still waiting for this decode; a cancelled caller stops counting.
        var waiters: Int
    }

    private let queue: DispatchQueue
    private let inFlight = Mutex<[ImageCache.Key: Entry]>([:])

    init(label: String) {
        queue = DispatchQueue(label: label, qos: .userInitiated)
    }

    /// The image for `key`: `cached()` when it has it, otherwise the running decode's result, otherwise a new decode
    /// queued behind any others. `decode` should fill the cache `cached` reads, so a request after it finishes is a
    /// cache hit. Nil when the decode found nothing, or when every caller was cancelled before its turn.
    func image(
        for key: ImageCache.Key,
        cached: @Sendable () -> CGImage?,
        decode: @escaping @Sendable () -> CGImage?
    ) async -> CGImage? {
        enum Start {
            case hit(CGImage)
            case wait(Task<CGImage?, Never>)
        }
        let start: Start = inFlight.withLock { inFlight in
            // Checked under the lock: a decode that finished since the caller's own cache check has filled it.
            if let image = cached() { return .hit(image) }
            if var entry = inFlight[key] {
                entry.waiters += 1
                inFlight[key] = entry
                return .wait(entry.task)
            }
            let task = Task { await self.run(key, decode: decode) }
            inFlight[key] = Entry(task: task, waiters: 1)
            return .wait(task)
        }
        let task: Task<CGImage?, Never>
        switch start {
        case .hit(let image): return image
        case .wait(let waiting): task = waiting
        }
        let image = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            inFlight.withLock { inFlight in
                if inFlight[key]?.task == task { inFlight[key]?.waiters -= 1 }
            }
        }
        inFlight.withLock { inFlight in
            // A later decode of the same page may have started since; leave it.
            if inFlight[key]?.task == task { inFlight[key] = nil }
        }
        return image
    }

    /// The decode on the serial queue, unless nobody is waiting any more by the time its turn comes.
    private func run(_ key: ImageCache.Key, decode: @escaping @Sendable () -> CGImage?) async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let wanted = inFlight.withLock { inFlight in
                    guard let entry = inFlight[key], entry.waiters > 0 else {
                        // Gone now, so a new request starts a fresh decode rather than joining this skipped one.
                        inFlight[key] = nil
                        return false
                    }
                    return true
                }
                continuation.resume(returning: wanted ? decode() : nil)
            }
        }
    }
}
