/// How the review's filing suggestion ended (M10).
public enum SuggestionOutcome: String, CaseIterable, AnalyticsToken {
    case arrived
    case timedOut
    case failed
    case unavailable
}
