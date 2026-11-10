/// A scan Search found (M15) and its result's second line (M16).
package struct SearchHit: Sendable, Equatable {
    /// Every word is in the title: the scan ranks with the title matches, first.
    package let titleMatches: Bool
    /// The first line of text holding a match, or the first line when only the title matched; "" without text.
    package let snippet: String
    /// Every match in `snippet`, to show in bold, in order.
    package let bold: [Range<String.Index>]
}
