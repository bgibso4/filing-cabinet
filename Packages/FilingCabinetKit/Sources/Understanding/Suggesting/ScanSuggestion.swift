/// What the on-device model suggests for filing a scan, after `SuggestionCleanup`. The hidden search words come from a
/// second call (`ScanSuggester.suggestWords`).
public struct ScanSuggestion: Sendable, Equatable {
    /// Bump when the prompt or schema changes enough that older scans' words should be read again (M1).
    package static let promptVersion = 1

    /// A short title, or nil when the model gave nothing usable.
    package let title: String?
    /// One of the collection ids the model was handed, or nil.
    package let collectionID: String?

    package init(title: String?, collectionID: String?) {
        self.title = title
        self.collectionID = collectionID
    }
}
