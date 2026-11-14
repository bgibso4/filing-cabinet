/// How the model is asked for a title: as one piece of text, or as a name and a kind that code joins.
public enum TitleStyle: String, Sendable, CaseIterable {
    /// One `title` property, written by the model.
    case whole
    /// A `name` (as printed, or empty) and a `kind` (1 to 2 words), joined by `SuggestionCleanup.composedTitle`.
    case parts
}
