/// The model's `name` and `kind` as it answered them, trimmed, before they were joined into a title. Kept so the
/// evaluation can tell which half missed.
package struct TitleParts: Sendable, Equatable {
    // periphery:ignore - read by the SuggestionEvaluation target, which Periphery doesn't scan
    package let name: String
    // periphery:ignore - read by the SuggestionEvaluation target, which Periphery doesn't scan
    package let kind: String

    package init(name: String, kind: String) {
        self.name = name
        self.kind = kind
    }
}
