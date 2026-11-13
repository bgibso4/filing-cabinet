/// What reading a whole scan found.
public struct ScanReading: Sendable, Equatable {
    /// What `searchText` puts between pages: a blank line, which Copy Text keeps (M11) and search skips.
    package static let pageSeparator = "\n\n"

    /// The suggested title, or nil when nothing readable sits near the top of page 1.
    package let title: String?
    /// Every recognized line of every page, joined by newlines, with `pageSeparator` between pages.
    package let searchText: String
    /// How many pages could not be read.
    public let failedPages: Int

    package init(title: String?, searchText: String, failedPages: Int) {
        self.title = title
        self.searchText = searchText
        self.failedPages = failedPages
    }
}
