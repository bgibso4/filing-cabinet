import Core
import CoreGraphics
import Library
import Synchronization
import Testing

@testable import ScreenModels
@testable import TestSupport

private func image() -> CGImage? {
    CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )?.makeImage()
}

/// Records every load. A held tile's load doesn't return until `release()`, or until its task is cancelled.
private nonisolated final class HeldThumbnails: ThumbnailProviding {
    private struct State {
        var held: Set<ScanID>
        var loaded: [ScanID] = []
        var finishPriorities: [TaskPriority] = []
    }

    private let state: Mutex<State>

    init(holding held: Set<ScanID>) {
        state = Mutex(State(held: held))
    }

    var loaded: [ScanID] { state.withLock { $0.loaded } }
    /// Each finished load's priority at the end of the load, by when any escalation has happened.
    var finishPriorities: [TaskPriority] { state.withLock { $0.finishPriorities } }

    func release() {
        state.withLock { $0.held = [] }
    }

    func cachedThumbnail(for id: ScanID, page: Int) -> CGImage? { nil }

    func thumbnail(for id: ScanID, page: Int) async -> CGImage? {
        state.withLock { _ = $0.loaded.append(id) }
        while state.withLock({ $0.held.contains(id) }), !Task.isCancelled {
            // A cancelled sleep only ends the wait early; the loop's check then stops it.
            try? await Task.sleep(for: .milliseconds(1))
        }
        state.withLock { $0.finishPriorities.append(Task.currentPriority) }
        return nil
    }
}

/// Waits for `count` loads, then a little longer to catch any extra ones. There is no deadline here: loads run at
/// `.utility` and a busy machine can hold them back for a long time, which is what that priority is for. A prefetcher
/// that really stalls fails on the tests' time limit, which cancels this wait.
private func drain(until count: Int, loaded: () -> Int) async {
    while loaded() < count, !Task.isCancelled {
        // A cancelled sleep only ends the wait early; the loop's check then stops it.
        try? await Task.sleep(for: .milliseconds(1))
    }
    // A cancelled sleep only shortens the wait; the expectations after it still run.
    try? await Task.sleep(for: .milliseconds(30))
}

private func drain(_ thumbnails: FakeThumbnails, until count: Int) async {
    await drain(until: count) { thumbnails.loadedRequests.count }
}

private func show(_ range: Range<Int>, of ids: [ScanID], on prefetcher: GridPrefetcher) {
    for index in range { prefetcher.tileAppeared(ids[index]) }
}

private func hide(_ range: Range<Int>, of ids: [ScanID], on prefetcher: GridPrefetcher) {
    for index in range { prefetcher.tileDisappeared(ids[index]) }
}

@Test(.timeLimit(.minutes(1))) func visibleTilesPrefetchTheWindowPastThem() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    await drain(thumbnails, until: 36)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<48]))
    #expect(thumbnails.loadedRequests.allSatisfy { $0.page == 0 })
}

@Test(.timeLimit(.minutes(1))) func aTileThatAppearsLeavesAndAppearsAgainWithNoLoadFinishedStillPrefetches() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    prefetcher.tileAppeared(ids[0])
    prefetcher.tileDisappeared(ids[0])
    prefetcher.tileAppeared(ids[0])
    await drain(thumbnails, until: 36)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[1..<37]))
}

@Test(.timeLimit(.minutes(1))) func aVisibleTileWhoseLoadNeverReturnsDoesNotBlockPrefetching() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = HeldThumbnails(holding: [ids[0]])
    defer { thumbnails.release() }
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    prefetcher.tileAppeared(ids[0])
    // What the tile's own view does.
    let visibleLoad = Task { await thumbnails.thumbnail(for: ids[0], page: 0) }
    defer { visibleLoad.cancel() }
    await drain(until: 37) { thumbnails.loaded.count }
    #expect(thumbnails.loaded.filter { $0 != ids[0] } == Array(ids[1..<37]))
}

@Test(.timeLimit(.minutes(1))) func eventsDuringTheQuietPeriodRestartItAndOnlyTheFinalRangeCounts() async throws {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .seconds(1))
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<6, of: ids, on: prefetcher)
    try await Task.sleep(for: .milliseconds(600))
    show(6..<12, of: ids, on: prefetcher)
    try await Task.sleep(for: .milliseconds(600))
    // 1.2 s after the first event, but only 0.6 s after the last.
    #expect(thumbnails.loadedRequests.isEmpty)
    await drain(thumbnails, until: 36)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<48]))
}

@Test(.timeLimit(.minutes(1))) func aChangeDuringALoadSetsTheNextLoadAndLoadsStayOneAtATime() async throws {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = HeldThumbnails(holding: [ids[12]])
    defer { thumbnails.release() }
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    await drain(until: 1) { thumbnails.loaded.count }

    hide(0..<12, of: ids, on: prefetcher)
    show(50..<62, of: ids, on: prefetcher)
    try await Task.sleep(for: .milliseconds(30))
    #expect(thumbnails.loaded == [ids[12]])

    thumbnails.release()
    await drain(until: 37) { thumbnails.loaded.count }
    #expect(thumbnails.loaded == [ids[12]] + Array(ids[62..<98]))
}

@Test(.timeLimit(.minutes(1))) func aLoadStaysAtLowPriorityWhileItRuns() async throws {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = HeldThumbnails(holding: [ids[1]])
    defer { thumbnails.release() }
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    prefetcher.tileAppeared(ids[0])
    await drain(until: 1) { thumbnails.loaded.count }
    // Long enough for anything waiting on the load to escalate it.
    try await Task.sleep(for: .milliseconds(30))
    thumbnails.release()
    await drain(until: 36) { thumbnails.finishPriorities.count }
    #expect(thumbnails.finishPriorities.count == 36)
    #expect(thumbnails.finishPriorities.allSatisfy { $0 == .utility })
}

@Test(.timeLimit(.minutes(1))) func theFirstScreenReportingBottomUpStillPrefetchesForward() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    for index in (0..<12).reversed() { prefetcher.tileAppeared(ids[index]) }
    await drain(thumbnails, until: 36)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<48]))
}

@Test(.timeLimit(.minutes(1))) func windowRollsForwardWithoutRepeatingWhatItTried() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    await drain(thumbnails, until: 36)

    show(12..<15, of: ids, on: prefetcher)
    hide(0..<3, of: ids, on: prefetcher)
    await drain(thumbnails, until: 39)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<51]))
}

@Test(.timeLimit(.minutes(1))) func scrollingBackPrefetchesAboveNearestFirst() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(50..<62, of: ids, on: prefetcher)
    await drain(thumbnails, until: 36)
    let down = thumbnails.loadedRequests.count

    show(49..<50, of: ids, on: prefetcher)
    await drain(thumbnails, until: down + 36)
    #expect(thumbnails.loadedRequests.dropFirst(down).map(\.id) == Array(ids[13..<49].reversed()))
}

@Test(.timeLimit(.minutes(1))) func theEndOfTheListPrefetchesNothing() async {
    let ids = (0..<20).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(8..<20, of: ids, on: prefetcher)
    await drain(thumbnails, until: 0)
    #expect(thumbnails.loadedRequests.isEmpty)
}

@Test(.timeLimit(.minutes(1))) func whatIsAlreadyInMemoryIsNotLoadedAgain() async throws {
    let ids = (0..<20).map { _ in ScanID() }
    let picture = try #require(image())
    let thumbnails = FakeThumbnails(images: [ids[3]: [0: picture]])
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<2, of: ids, on: prefetcher)
    await drain(thumbnails, until: 17)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[2..<3] + ids[4..<20]))
}

@Test(.timeLimit(.minutes(1))) func stoppingCancelsThePrefetch() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    prefetcher.stop()
    await drain(thumbnails, until: 0)
    #expect(thumbnails.loadedRequests.isEmpty)
}

@Test(.timeLimit(.minutes(1))) func noVisibleTilesMeansNoPrefetch() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = FakeThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    await drain(thumbnails, until: 0)
    #expect(thumbnails.loadedRequests.isEmpty)
}
