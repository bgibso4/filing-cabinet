/// What the on-device model suggests for a scan, after `SuggestionCleanup`.
public struct ScanSuggestion: Sendable, Equatable {
    // periphery:ignore - stored with the words from Plan 5 Task 5; remove this line then
    /// Bump when the prompt or schema changes enough that older scans' words should be read again (M1).
    package static let promptVersion = 1

    /// A short title, or nil when the model gave nothing usable.
    package let title: String?
    /// One of the collection ids the model was handed, or nil.
    package let collectionID: String?
    /// Hidden search words: never shown as a list.
    package let searchWords: [String]

    package init(title: String?, collectionID: String?, searchWords: [String]) {
        self.title = title
        self.collectionID = collectionID
        self.searchWords = searchWords
    }
}
