/// The seam through which the app reports what happened. A real provider is connected later;
/// until then `LogAnalytics` stands in.
public protocol Analytics: Sendable {
    func send(_ event: AnalyticsEvent)
}
