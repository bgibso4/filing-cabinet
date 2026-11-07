import Core
import CoreGraphics
import Synchronization

/// A small least-recently-used cache of decoded images, safe to share across tasks.
final class ImageCache: Sendable {
    struct Key: Hashable, Sendable {
        // periphery:ignore - read only by the synthesized Hashable and Equatable
        let id: ScanID
        // periphery:ignore - read only by the synthesized Hashable and Equatable
        let page: Int
    }

    private struct State {
        var images: [Key: CGImage] = [:]
        /// Least recently used first.
        var order: [Key] = []
    }

    private let capacity: Int
    private let state = Mutex(State())

    init(capacity: Int) {
        self.capacity = capacity
    }

    /// The cached image, marking it most recently used.
    func image(for key: Key) -> CGImage? {
        state.withLock { state in
            guard let image = state.images[key] else { return nil }
            state.order.removeAll { $0 == key }
            state.order.append(key)
            return image
        }
    }

    func insert(_ image: CGImage, for key: Key) {
        state.withLock { state in
            state.images[key] = image
            state.order.removeAll { $0 == key }
            state.order.append(key)
            while state.order.count > capacity {
                state.images[state.order.removeFirst()] = nil
            }
        }
    }
}
