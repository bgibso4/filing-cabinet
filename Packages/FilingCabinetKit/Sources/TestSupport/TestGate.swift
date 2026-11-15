/// Test double: holds back whatever waits on it until the test opens it, so a test sets the order of events instead
/// of timing them. Once open it stays open. A cancelled wait ends early.
package final class TestGate: Sendable {
    private let stream: AsyncStream<Never>
    private let continuation: AsyncStream<Never>.Continuation

    package init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    /// Lets every wait, now and later, go on.
    package func open() {
        continuation.finish()
    }

    /// Returns once the gate is open, or when the waiting task is cancelled.
    package func wait() async {
        // A finished stream ends iteration for every waiter; cancellation ends it for this one.
        for await _ in stream {}
    }
}
