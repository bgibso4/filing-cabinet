/// How long a scan stays in a collection before cleanup considers it.
public enum Lifespan: String, Sendable, CaseIterable {
    case week
    case threeMonths
    case forever
}
