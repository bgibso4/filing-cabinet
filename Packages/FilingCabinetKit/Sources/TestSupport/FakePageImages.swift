import Core
import CoreGraphics
import Library
import Synchronization

/// Serves preloaded pages from both methods and records every request.
public final class FakePageImages: PageImageProviding {
    private struct State {
        var images: [ScanID: [Int: CGImage]]
        var requests: [FakeImageRequest] = []
    }

    private let state: Mutex<State>

    /// `images[id][index]` is the image for that page.
    public init(images: [ScanID: [Int: CGImage]] = [:]) {
        state = Mutex(State(images: images))
    }

    /// Every request, in order, from both `cachedPage` and `page`.
    package var requests: [FakeImageRequest] { state.withLock { $0.requests } }

    /// Only the async loads: what a view actually asked the disk side for.
    package var loadedRequests: [FakeImageRequest] { requests.filter { $0.kind == .loaded } }

    /// The distinct scans among the async loads, in first-request order.
    package var loadedIDs: [ScanID] {
        var seen: [ScanID] = []
        for request in loadedRequests where !seen.contains(request.id) { seen.append(request.id) }
        return seen
    }

    public func cachedPage(for id: ScanID, index: Int) -> CGImage? {
        serve(id, index, .cached)
    }

    public func page(for id: ScanID, index: Int) async -> CGImage? {
        serve(id, index, .loaded)
    }

    private func serve(_ id: ScanID, _ page: Int, _ kind: FakeImageRequest.Kind) -> CGImage? {
        state.withLock { state in
            state.requests.append(FakeImageRequest(id: id, page: page, kind: kind))
            return state.images[id]?[page]
        }
    }
}
