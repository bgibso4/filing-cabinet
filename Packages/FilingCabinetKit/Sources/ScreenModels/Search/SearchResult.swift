import Core

/// One row of Search's results (08-03).
package struct SearchResult: Equatable, Identifiable {
    package let id: ScanID
    package let title: String
    /// The first line of text holding a match, or the first line when only the title matched (M16).
    package let snippet: String
    /// Every match in `snippet`, to show in bold.
    package let bold: [Range<String.Index>]
    /// The dot's colour.
    package let collection: BuiltInCollection
    /// The third line: "Documents · Oct 1", with the year when it isn't this one.
    package let detail: String
}
