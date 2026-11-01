import Core
import Synchronization

/// Test double that remembers every event, in order.
public final class RecordingAnalytics: Analytics {
    private let recorded = Mutex<[AnalyticsEvent]>([])

    public init() {}

    public var events: [AnalyticsEvent] { recorded.withLock { $0 } }

    public func send(_ event: AnalyticsEvent) {
        recorded.withLock { $0.append(event) }
    }
}
