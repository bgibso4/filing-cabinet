import Core
import Library
import Synchronization

/// Test double for `SpotlightIndexing`, also built by the app under `-UITest` so no run touches the phone's index:
/// keeps what is indexed in memory and records every call.
public final class FakeSpotlightIndex: SpotlightIndexing {
    /// One call to the index.
    package enum Call: Equatable, Sendable {
        case index([ScanID])
        case remove([ScanID])
        case removeAll
    }

    /// The error the fake throws.
    package struct Failure: Error {}

    private struct State {
        var items: [ScanID: SpotlightItem] = [:]
        var calls: [Call] = []
        var failNext = false
    }

    private let state = Mutex(State())

    public init() {}

    /// What the index holds now.
    package var items: [ScanID: SpotlightItem] { state.withLock { $0.items } }

    /// Every call, in order, the failed one included.
    package var calls: [Call] { state.withLock { $0.calls } }

    /// The next call throws and changes nothing.
    package func failNextCall() {
        state.withLock { $0.failNext = true }
    }

    public func index(_ items: [SpotlightItem]) async throws {
        try record(.index(items.map(\.id))) { state in
            for item in items { state.items[item.id] = item }
        }
    }

    public func remove(_ ids: [ScanID]) async throws {
        try record(.remove(ids)) { state in
            for id in ids { state.items[id] = nil }
        }
    }

    public func removeAll() async throws {
        try record(.removeAll) { $0.items = [:] }
    }

    private func record(_ call: Call, _ change: (inout State) -> Void) throws {
        try state.withLock { state in
            state.calls.append(call)
            if state.failNext {
                state.failNext = false
                throw Failure()
            }
            change(&state)
        }
    }
}
