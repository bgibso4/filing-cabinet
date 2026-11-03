/// Which on-device text reader understands a page. Lives in Core so launch options can name one.
public enum ReaderKind: String, Sendable, CaseIterable {
    /// Vision's line-level text recognizer.
    case text
    /// Vision's document recognizer (structure-aware, finds titles).
    case documents
}
