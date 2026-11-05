/// A scan's own expiry, set instead of its collection's. No override means the collection default.
public enum ExpiryOverride: Sendable, Hashable {
    case lifespan(Lifespan)
    case lastDay(CalendarDay)
}
