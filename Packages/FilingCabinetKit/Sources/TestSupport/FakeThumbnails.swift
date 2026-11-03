import Core
import CoreGraphics
import Library
import Synchronization

/// Serves preloaded thumbnails from both methods and records every request, so performance tests can
/// assert which pages a grid asked for.
package final class FakeThumbnails: ThumbnailProviding {
    private struct State {
        var images: [ScanID: [Int: CGImage]]
        var requests: [FakeImageRequest] = []
    }

    private let state: Mutex<State>

    /// `images[id][page]` is the thumbnail for that page.
    package init(images: [ScanID: [Int: CGImage]] = [:]) {
        state = Mutex(State(images: images))
    }

    /// Every request, in order, from both `cachedThumbnail` and `thumbnail`.
    package var requests: [FakeImageRequest] { state.withLock { $0.requests } }

    /// Only the async loads: what a view actually asked the disk side for.
    package var loadedRequests: [FakeImageRequest] { requests.filter { $0.kind == .loaded } }

    /// The distinct scans among the async loads, in first-request order.
    package var loadedIDs: [ScanID] {
        var seen: [ScanID] = []
        for request in loadedRequests where !seen.contains(request.id) { seen.append(request.id) }
        return seen
    }

    package func cachedThumbnail(for id: ScanID, page: Int) -> CGImage? {
        serve(id, page, .cached)
    }

    package func thumbnail(for id: ScanID, page: Int) async -> CGImage? {
        serve(id, page, .loaded)
    }

    private func serve(_ id: ScanID, _ page: Int, _ kind: FakeImageRequest.Kind) -> CGImage? {
        state.withLock { state in
            state.requests.append(FakeImageRequest(id: id, page: page, kind: kind))
            return state.images[id]?[page]
        }
    }
}
