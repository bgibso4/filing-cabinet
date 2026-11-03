import Core
import CoreGraphics
import Library
import Synchronization

/// Serves preloaded thumbnails from both methods and records every request, so performance tests can
/// assert which pages a grid asked for.
package final class FakeThumbnails: ThumbnailProviding {
    private struct State {
        var images: [ScanID: [Int: CGImage]]
        var requests: [Request] = []
    }

    package struct Request: Equatable, Sendable {
        package let id: ScanID
        package let page: Int

        package init(id: ScanID, page: Int) {
            self.id = id
            self.page = page
        }
    }

    private let state: Mutex<State>

    /// `images[id][page]` is the thumbnail for that page.
    package init(images: [ScanID: [Int: CGImage]] = [:]) {
        state = Mutex(State(images: images))
    }

    /// Every request, in order, from both `cachedThumbnail` and `thumbnail`.
    package var requests: [Request] { state.withLock { $0.requests } }

    package func cachedThumbnail(for id: ScanID, page: Int) -> CGImage? {
        serve(id, page)
    }

    package func thumbnail(for id: ScanID, page: Int) async -> CGImage? {
        serve(id, page)
    }

    private func serve(_ id: ScanID, _ page: Int) -> CGImage? {
        state.withLock { state in
            state.requests.append(Request(id: id, page: page))
            return state.images[id]?[page]
        }
    }
}
