import Core
import Library

/// Loads page 0 of the tiles just past the visible ones, so they are in memory when they scroll in. The visible tiles
/// go first: their own loads start as they appear, at normal priority, and this waits for a quiet period after that.
/// Loads run one at a time at low priority, away from the main actor (`ThumbnailProviding`), so one never delays a
/// visible tile.
package final class GridPrefetcher {
    /// A layout pass reports its tiles over several main-actor turns, in no promised order. Until they stop arriving,
    /// a tile can look like the only visible one and its neighbours like the window, or the first screen like an
    /// upward scroll.
    private static let layoutQuietPeriod = Duration.milliseconds(50)

    private let quietPeriod: Duration
    private let sleep: (Duration) async -> Void
    private var ids: [ScanID] = []
    private var indexes: [ScanID: Int] = [:]
    private var provider: (any ThumbnailProviding)?

    private var visible: Set<ScanID> = []
    /// The visible range after the last quiet period.
    private var lastRange: ClosedRange<Int>?
    private var direction = GridPrefetchWindow.Direction.forward
    private var window: [ScanID] = []
    /// What this window has tried, so a thumbnail that can't load isn't asked for forever.
    private var attempted: Set<ScanID> = []
    private var waiting: Task<Void, Never>?
    private var loading: Task<Void, Never>?

    /// Tests with no layout pass to wait for use a `quietPeriod` of zero or close to it. `sleep` is how a quiet period
    /// passes: a test scripts it to prove restarts without a wall clock. It returns early when its task is cancelled.
    package init(
        quietPeriod: Duration = layoutQuietPeriod,
        sleep: @escaping (Duration) async -> Void = { duration in
            // A cancelled sleep ends early, and the caller's check stops the work.
            try? await Task.sleep(for: duration)
        }
    ) {
        self.quietPeriod = quietPeriod
        self.sleep = sleep
    }

    /// The grid's tiles, in order, and where their thumbnails come from.
    package func update(ids: [ScanID], provider: any ThumbnailProviding) {
        self.ids = ids
        self.provider = provider
        indexes = Dictionary(ids.enumerated().map { ($1, $0) }) { first, _ in first }
        refreshWhenQuiet()
    }

    package func tileAppeared(_ id: ScanID) {
        visible.insert(id)
        refreshWhenQuiet()
    }

    package func tileDisappeared(_ id: ScanID) {
        visible.remove(id)
        refreshWhenQuiet()
    }

    /// The grid went away. The tiles report in again if it comes back.
    package func stop() {
        waiting?.cancel()
        waiting = nil
        loading?.cancel()
        loading = nil
        visible = []
        lastRange = nil
        window = []
        attempted = []
    }

    private func refreshWhenQuiet() {
        waiting?.cancel()
        waiting = Task { [weak self, quietPeriod, sleep] in
            await sleep(quietPeriod)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// Moves the window to the visible range and loads from it. Direction is judged between quiet ranges.
    private func refresh() {
        let visibleIndexes = visible.compactMap { indexes[$0] }
        guard let first = visibleIndexes.min(), let last = visibleIndexes.max() else {
            window = []
            return
        }
        let range = first...last
        direction = GridPrefetchWindow.direction(from: lastRange, to: range, current: direction)
        lastRange = range
        window = GridPrefetchWindow.indexes(visible: range, direction: direction, total: ids.count).map { ids[$0] }
        attempted.formIntersection(window)
        pump()
    }

    /// Starts the next load unless one is running; that one starts the next from whatever the window is by then.
    private func pump() {
        guard loading == nil, let provider, let next = nextToLoad(from: provider) else { return }
        // The load reports back instead of being awaited: anything of higher priority awaiting it would escalate it.
        loading = Task(priority: .utility) { @concurrent [weak self] in
            _ = await provider.thumbnail(for: next, page: 0)
            await MainActor.run {
                // On the main actor, like `stop()`, so a stopped load can't touch a later one's state.
                guard !Task.isCancelled else { return }
                self?.loading = nil
                self?.pump()
            }
        }
    }

    /// The nearest window tile not yet tried or in memory.
    private func nextToLoad(from provider: any ThumbnailProviding) -> ScanID? {
        let next = window.first { id in
            !attempted.contains(id) && provider.cachedThumbnail(for: id, page: 0) == nil
        }
        if let next { attempted.insert(next) }
        return next
    }
}
