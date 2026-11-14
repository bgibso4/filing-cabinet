import Observation

/// The request from outside the app still waiting to be acted on. One per process, made before any intent can run; the
/// root takes it once nothing is in the way (Plan 6 §7, M9). It holds one request: a newer one replaces an older one,
/// and a second Scan before the first was taken is the same Scan, so it makes one camera.
@MainActor
@Observable
public final class ExternalRequests {
    public private(set) var pending: ExternalRequest?

    public init() {}

    public func send(_ request: ExternalRequest) {
        // The same request again changes nothing, so it doesn't wake the root.
        guard request != pending else { return }
        pending = request
    }

    /// The pending request, which is no longer pending.
    public func take() -> ExternalRequest? {
        defer { pending = nil }
        return pending
    }
}
