import Core
import Foundation

/// One row of Search's results (08-03).
package struct SearchResult: Equatable, Identifiable {
    /// What the row's second line says.
    package enum SecondLine: Equatable {
        /// The first line of text holding a match, or the first line when only the title matched, with every match
        /// in it to show in bold (M16).
        case snippet(String, bold: [Range<String.Index>])
        /// Only hidden words found the scan: a sparkle and "Matches ‹query›" (M8).
        case hiddenWord(query: String)
    }

    package let id: ScanID
    package let title: String
    /// The second line (M16, M8).
    package let secondLine: SecondLine
    /// The dot's colour.
    package let collection: BuiltInCollection
    /// The third line: "Documents · Oct 1", with the year when it isn't this one.
    package let detail: String
    /// What VoiceOver reads for the whole row: "Lease 2026, Documents, October 1, Re: Lease renewal…".
    package let accessibilityLabel: String

    /// "Matches ID": the hidden-word row's text (M8), which the row draws with the query in bold.
    package static func matchesLine(_ query: String) -> String {
        String(localized: "Matches \(query)", bundle: #bundle)
    }
}
