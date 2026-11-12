/// Whether the suggester can answer at all right now.
public enum SuggesterAvailability: Sendable, Equatable {
    case available
    case unavailable
}

/// Suggests a title, a collection and hidden search words for a scan.
public protocol ScanSuggester: Sendable {
    // periphery:ignore - read by the review flow from Plan 5 Task 8; remove this line then
    /// Read fresh each time: Apple Intelligence can be turned off or finish downloading while the app runs.
    var availability: SuggesterAvailability { get }

    // periphery:ignore - called by the review flow from Plan 5 Task 8; remove this line then
    /// The suggestion, or nil on any failure or cancellation. Never throws: no error is ever shown for the model.
    func suggest(_ input: SuggestionInput) async -> ScanSuggestion?
}
