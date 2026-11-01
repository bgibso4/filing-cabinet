/// Every event the app can report. Payload keys and values are typed, so an event cannot carry
/// free text.
public enum AnalyticsEvent: Sendable, Equatable {
    case appOpened

    public var name: String {
        switch self {
        case .appOpened: "appOpened"
        }
    }

    public var payload: [AnalyticsKey: AnalyticsValue] {
        switch self {
        case .appOpened: [:]
        }
    }
}

/// Payload keys. Empty until an event needs one; the first key adds the `String` raw type
/// (an enum with no cases cannot declare one).
public enum AnalyticsKey: Hashable, Sendable {}
