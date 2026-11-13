@testable import ScreenModels

/// Records each request for background time, and can run out of it the way iOS does.
final class FakeBackgroundTime: BackgroundTime {
    /// The name of every job that asked, in order.
    private(set) var begun: [String] = []
    /// How many jobs ended their time.
    private(set) var ended = 0
    private var expirations: [@MainActor @Sendable () -> Void] = []

    func begin(_ name: String, expired: @escaping @MainActor @Sendable () -> Void) -> () -> Void {
        begun.append(name)
        expirations.append(expired)
        return { self.ended += 1 }
    }

    /// iOS's time runs out for every job that asked.
    func expire() {
        for expired in expirations { expired() }
    }
}
