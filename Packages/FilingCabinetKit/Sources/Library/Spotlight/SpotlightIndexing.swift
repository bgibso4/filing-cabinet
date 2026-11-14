import Core

/// Where scans are indexed for iPhone search. `CoreSpotlightIndex` is the real one; `FakeSpotlightIndex` stands in for
/// tests and UI tests.
public protocol SpotlightIndexing: Sendable {
    /// Adds the items, replacing any with the same scan.
    func index(_ items: [SpotlightItem]) async throws
    func remove(_ ids: [ScanID]) async throws
    func removeAll() async throws
}
