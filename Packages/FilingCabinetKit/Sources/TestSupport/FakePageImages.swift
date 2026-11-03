import Core
import CoreGraphics
import Library
import Synchronization

/// Serves preloaded pages from both methods and records every request.
package final class FakePageImages: PageImageProviding {
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

    /// `images[id][index]` is the image for that page.
    package init(images: [ScanID: [Int: CGImage]] = [:]) {
        state = Mutex(State(images: images))
    }

    /// Every request, in order, from both `cachedPage` and `page`.
    package var requests: [Request] { state.withLock { $0.requests } }

    package func cachedPage(for id: ScanID, index: Int) -> CGImage? {
        serve(id, index)
    }

    package func page(for id: ScanID, index: Int) async -> CGImage? {
        serve(id, index)
    }

    private func serve(_ id: ScanID, _ page: Int) -> CGImage? {
        state.withLock { state in
            state.requests.append(Request(id: id, page: page))
            return state.images[id]?[page]
        }
    }
}
