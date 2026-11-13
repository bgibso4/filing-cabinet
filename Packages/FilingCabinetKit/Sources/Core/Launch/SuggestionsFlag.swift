/// `-Suggestions`: which scripted suggester the review uses (M5).
public enum SuggestionsFlag: String, Sendable, Equatable {
    /// The City Pharmacy receipt in Receipts, after 0.3 s; its words after Save, as fast.
    case arrives
    /// Never answers, so the card grows into the sheet at the wait limit.
    case slow
    /// Apple Intelligence isn't available: today's full sheet.
    case unavailable
}
