import Core
import CoreGraphics
import Foundation
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
    /// Counts loads as they start, and as they finish.
    let started = CountSignal()
    let finished = CountSignal()

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
        started.increment()
        while state.withLock({ $0.held.contains(id) }), !Task.isCancelled {
            // A cancelled sleep only ends the wait early; the loop's check then stops it.
            try? await Task.sleep(for: .milliseconds(1))
        }
        state.withLock { $0.finishPriorities.append(Task.currentPriority) }
        finished.increment()
        return nil
    }
}

/// A count that tasks can wait on: `wait(for:)` returns once `increment()` has been called that many times. Waiting
/// has no deadline of its own: loads run at `.utility` and a busy machine can hold them back for a long time, which is
/// what that priority is for. A prefetcher that really stalls fails on the tests' time limit, which cancels the wait.
private nonisolated final class CountSignal: Sendable {
    private struct Waiter {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct State {
        var count = 0
        var waiters: [UUID: Waiter] = [:]
    }

    private let state = Mutex(State())

    func increment() {
        let ready = state.withLock { state -> [Waiter] in
            state.count += 1
            let ready = state.waiters.filter { $0.value.target <= state.count }
            for id in ready.keys { state.waiters[id] = nil }
            return Array(ready.values)
        }
        for waiter in ready { waiter.continuation.resume() }
    }

    func wait(for target: Int) async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let done = state.withLock { state -> Bool in
                    if state.count >= target || Task.isCancelled { return true }
                    state.waiters[id] = Waiter(target: target, continuation: continuation)
                    return false
                }
                if done { continuation.resume() }
            }
        } onCancel: {
            let waiter = state.withLock { $0.waiters.removeValue(forKey: id) }
            waiter?.continuation.resume()
        }
    }
}

/// `FakeThumbnails` that signals each finished async load.
private nonisolated final class SignalingThumbnails: ThumbnailProviding {
    private let fake: FakeThumbnails
    let loads = CountSignal()

    init(images: [ScanID: [Int: CGImage]] = [:]) {
        fake = FakeThumbnails(images: images)
    }

    var loadedRequests: [FakeImageRequest] { fake.loadedRequests }

    func cachedThumbnail(for id: ScanID, page: Int) -> CGImage? { fake.cachedThumbnail(for: id, page: page) }

    func thumbnail(for id: ScanID, page: Int) async -> CGImage? {
        let image = await fake.thumbnail(for: id, page: page)
        loads.increment()
        return image
    }
}

/// The quiet period as a script: each sleep waits until the test releases it, and ends early on cancellation like
/// `Task.sleep`.
private nonisolated final class ScriptedQuietPeriod: Sendable {
    private struct State {
        var released = false
        var sleepers: [UUID: CheckedContinuation<Void, Never>] = [:]
    }

    private let state = Mutex(State())
    let started = CountSignal()

    func sleep(_: Duration) async {
        let id = UUID()
        started.increment()
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let done = state.withLock { state -> Bool in
                    if state.released || Task.isCancelled { return true }
                    state.sleepers[id] = continuation
                    return false
                }
                if done { continuation.resume() }
            }
        } onCancel: {
            state.withLock { $0.sleepers.removeValue(forKey: id) }?.resume()
        }
    }

    /// Ends every sleep, now and later.
    func release() {
        let sleepers = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            state.released = true
            defer { state.sleepers = [:] }
            return Array(state.sleepers.values)
        }
        for continuation in sleepers { continuation.resume() }
    }
}

/// Waits for `count` signals, then a little longer to catch any extra ones.
private func drain(_ signal: CountSignal, until count: Int) async {
    await signal.wait(for: count)
    // A cancelled sleep only shortens the wait; the expectations after it still run.
    try? await Task.sleep(for: .milliseconds(30))
}

private func show(_ range: Range<Int>, of ids: [ScanID], on prefetcher: GridPrefetcher) {
    for index in range { prefetcher.tileAppeared(ids[index]) }
}

private func hide(_ range: Range<Int>, of ids: [ScanID], on prefetcher: GridPrefetcher) {
    for index in range { prefetcher.tileDisappeared(ids[index]) }
}

@Test(.timeLimit(.minutes(1))) func visibleTilesPrefetchTheWindowPastThem() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    await drain(thumbnails.loads, until: 36)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<48]))
    #expect(thumbnails.loadedRequests.allSatisfy { $0.page == 0 })
}

@Test(.timeLimit(.minutes(1))) func aTileThatAppearsLeavesAndAppearsAgainWithNoLoadFinishedStillPrefetches() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    prefetcher.tileAppeared(ids[0])
    prefetcher.tileDisappeared(ids[0])
    prefetcher.tileAppeared(ids[0])
    await drain(thumbnails.loads, until: 36)
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
    await drain(thumbnails.started, until: 37)
    #expect(thumbnails.loaded.filter { $0 != ids[0] } == Array(ids[1..<37]))
}

@Test(.timeLimit(.minutes(1))) func eventsDuringTheQuietPeriodRestartItAndOnlyTheFinalRangeCounts() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let quietPeriod = ScriptedQuietPeriod()
    let prefetcher = GridPrefetcher(quietPeriod: .seconds(1), sleep: quietPeriod.sleep)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<6, of: ids, on: prefetcher)
    show(6..<12, of: ids, on: prefetcher)
    // Every event started a quiet period (update's too) and cancelled the one before it. None has ended yet.
    await quietPeriod.started.wait(for: 13)
    #expect(thumbnails.loadedRequests.isEmpty)
    // Now every one of them ends, the cancelled ones included: only the last may act.
    quietPeriod.release()
    await drain(thumbnails.loads, until: 36)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<48]))
}

@Test(.timeLimit(.minutes(1))) func aChangeDuringALoadSetsTheNextLoadAndLoadsStayOneAtATime() async throws {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = HeldThumbnails(holding: [ids[12]])
    defer { thumbnails.release() }
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    await drain(thumbnails.started, until: 1)

    hide(0..<12, of: ids, on: prefetcher)
    show(50..<62, of: ids, on: prefetcher)
    try await Task.sleep(for: .milliseconds(30))
    #expect(thumbnails.loaded == [ids[12]])

    thumbnails.release()
    await drain(thumbnails.started, until: 37)
    #expect(thumbnails.loaded == [ids[12]] + Array(ids[62..<98]))
}

@Test(.timeLimit(.minutes(1))) func aLoadStaysAtLowPriorityWhileItRuns() async throws {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = HeldThumbnails(holding: [ids[1]])
    defer { thumbnails.release() }
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    prefetcher.tileAppeared(ids[0])
    await drain(thumbnails.started, until: 1)
    // Long enough for anything waiting on the load to escalate it.
    try await Task.sleep(for: .milliseconds(30))
    thumbnails.release()
    await drain(thumbnails.finished, until: 36)
    #expect(thumbnails.finishPriorities.count == 36)
    #expect(thumbnails.finishPriorities.allSatisfy { $0 == .utility })
}

@Test(.timeLimit(.minutes(1))) func theFirstScreenReportingBottomUpStillPrefetchesForward() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    for index in (0..<12).reversed() { prefetcher.tileAppeared(ids[index]) }
    await drain(thumbnails.loads, until: 36)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<48]))
}

@Test(.timeLimit(.minutes(1))) func windowRollsForwardWithoutRepeatingWhatItTried() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    await drain(thumbnails.loads, until: 36)

    show(12..<15, of: ids, on: prefetcher)
    hide(0..<3, of: ids, on: prefetcher)
    await drain(thumbnails.loads, until: 39)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[12..<51]))
}

@Test(.timeLimit(.minutes(1))) func scrollingBackPrefetchesAboveNearestFirst() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(50..<62, of: ids, on: prefetcher)
    await drain(thumbnails.loads, until: 36)
    let down = thumbnails.loadedRequests.count

    show(49..<50, of: ids, on: prefetcher)
    await drain(thumbnails.loads, until: down + 36)
    #expect(thumbnails.loadedRequests.dropFirst(down).map(\.id) == Array(ids[13..<49].reversed()))
}

@Test(.timeLimit(.minutes(1))) func theEndOfTheListPrefetchesNothing() async {
    let ids = (0..<20).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(8..<20, of: ids, on: prefetcher)
    await drain(thumbnails.loads, until: 0)
    #expect(thumbnails.loadedRequests.isEmpty)
}

@Test(.timeLimit(.minutes(1))) func whatIsAlreadyInMemoryIsNotLoadedAgain() async throws {
    let ids = (0..<20).map { _ in ScanID() }
    let picture = try #require(image())
    let thumbnails = SignalingThumbnails(images: [ids[3]: [0: picture]])
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<2, of: ids, on: prefetcher)
    await drain(thumbnails.loads, until: 17)
    #expect(thumbnails.loadedRequests.map(\.id) == Array(ids[2..<3] + ids[4..<20]))
}

@Test(.timeLimit(.minutes(1))) func stoppingCancelsThePrefetch() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    show(0..<12, of: ids, on: prefetcher)
    prefetcher.stop()
    await drain(thumbnails.loads, until: 0)
    #expect(thumbnails.loadedRequests.isEmpty)
}

@Test(.timeLimit(.minutes(1))) func noVisibleTilesMeansNoPrefetch() async {
    let ids = (0..<100).map { _ in ScanID() }
    let thumbnails = SignalingThumbnails()
    let prefetcher = GridPrefetcher(quietPeriod: .zero)
    prefetcher.update(ids: ids, provider: thumbnails)
    await drain(thumbnails.loads, until: 0)
    #expect(thumbnails.loadedRequests.isEmpty)
}
