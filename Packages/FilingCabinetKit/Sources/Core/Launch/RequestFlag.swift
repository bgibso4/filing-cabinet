/// `-Request scan|search:<text>|open:<n>|trash`: a request from outside the app, sent at launch so UI tests can reach the
/// routing (M15). `open:<n>` is the nth scan `-SeedScans` saves, from 1, in seed order.
public enum RequestFlag: Sendable, Equatable {
    case scan
    case search(String)
    case open(seeded: Int)
    case trash

    /// Nil when the value is none of the four, or its text or number is missing.
    init?(_ value: String) {
        if value == "scan" {
            self = .scan
            return
        }
        if value == "trash" {
            self = .trash
            return
        }
        guard let colon = value.firstIndex(of: ":") else { return nil }
        let rest = String(value[value.index(after: colon)...])
        switch value[..<colon] {
        case "search" where !rest.isEmpty:
            self = .search(rest)
        case "open":
            guard let number = Int(rest), number >= 1 else { return nil }
            self = .open(seeded: number)
        default:
            return nil
        }
    }
}
