/// Whether the suggester can answer at all right now.
public enum SuggesterAvailability: Sendable, Equatable {
    case available
    case unavailable
}

/// Suggests a title and a collection for a scan while it is reviewed, then its hidden search words once it is saved
/// (two calls, so the review waits only for the first).
public protocol ScanSuggester: Sendable {
    /// Read fresh each time: Apple Intelligence can be turned off or finish downloading while the app runs.
    var availability: SuggesterAvailability { get }

    /// The title and collection (`searchWords` empty), or nil on any failure or cancellation. Never throws: no error
    /// is ever shown for the model.
    func suggestFiling(_ input: SuggestionInput) async -> ScanSuggestion?

    /// Hidden search words for a scan filed as `title` in the collection named `collectionName`, cleaned (at most 8),
    /// or nil on any failure or cancellation.
    func suggestWords(_ input: SuggestionInput, title: String, collectionName: String) async -> [String]?

    /// Gets the model ready for a `suggestFiling` with these collections soon (E3: called when the camera opens).
    /// Cheap, returns at once and is safe to call again.
    func prewarm(collections: [SuggestionCollection])
}
