import Core
import CoreGraphics
import Dispatch
import Synchronization
import TestSupport
import Testing

@testable import Library

/// Records which keys were decoded, and holds a decode open until released.
private final class DecodeLog: Sendable {
    private let decoded = Mutex<[Int]>([])
    private let started = Mutex(false)
    private let gate = DispatchSemaphore(value: 0)

    var pages: [Int] { decoded.withLock { $0 } }
    var hasStarted: Bool { started.withLock { $0 } }

    func release() { gate.signal() }

    /// A decode that blocks until `release()`.
    func slow(_ page: Int) -> CGImage? {
        started.withLock { $0 = true }
        gate.wait()
        decoded.withLock { $0.append(page) }
        return SyntheticPages.blank()
    }

    func quick(_ page: Int) -> CGImage? {
        decoded.withLock { $0.append(page) }
        return SyntheticPages.blank()
    }
}

/// Polls until `condition` holds; false if it never did.
private func eventually(_ condition: () -> Bool) async throws -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try await Task.sleep(for: .milliseconds(10))
    }
    return false
}

@Test func aCancelledRequestQueuedBehindASlowDecodeNeverDecodes() async throws {
    let queue = ImageDecodeQueue(label: "test")
    let log = DecodeLog()
    let id = ScanID()
    let slowKey = ImageCache.Key(id: id, page: 0)
    let skippedKey = ImageCache.Key(id: id, page: 1)

    let slow = Task {
        await queue.image(for: slowKey) {
            nil
        } decode: {
            log.slow(0)
        }
    }
    #expect(try await eventually { log.hasStarted })
    let skipped = Task {
        await queue.image(for: skippedKey) {
            nil
        } decode: {
            log.quick(1)
        }
    }
    skipped.cancel()
    log.release()

    #expect(await slow.value != nil)
    #expect(await skipped.value == nil)
    #expect(log.pages == [0])
}

@Test func aRequestStillWantedAlongsideACancelledOneIsDecoded() async throws {
    let queue = ImageDecodeQueue(label: "test")
    let log = DecodeLog()
    let id = ScanID()
    let slowKey = ImageCache.Key(id: id, page: 0)
    let sharedKey = ImageCache.Key(id: id, page: 1)

    let slow = Task {
        await queue.image(for: slowKey) {
            nil
        } decode: {
            log.slow(0)
        }
    }
    #expect(try await eventually { log.hasStarted })
    let cancelled = Task {
        await queue.image(for: sharedKey) {
            nil
        } decode: {
            log.quick(1)
        }
    }
    let wanted = Task {
        await queue.image(for: sharedKey) {
            nil
        } decode: {
            log.quick(1)
        }
    }
    cancelled.cancel()
    log.release()

    _ = await slow.value
    _ = await cancelled.value
    #expect(await wanted.value != nil)
    #expect(log.pages == [0, 1])
}
