import Foundation

/// How Search matches a scan (M15) and what its result's second line shows (M16). The only place Search ranks or
/// builds snippets.
///
/// Matching follows E3: every title, text and term is folded once (case and accents), and each term is found with
/// `memmem` over the folded UTF-8 bytes, which keeps a pass over 2,000 scans under 2 ms. Folding can change length
/// ("ß" folds to "ss", ligatures expand), so the snippet and its bold are worked out on the original line, with a
/// case- and accent-insensitive compare, and only for a scan that matched.
package enum SearchMatch {
    /// A string with its folded UTF-8 bytes, made once and kept (the model keeps one per title and text).
    package struct Folded: Sendable {
        package let original: String
        package let bytes: [UInt8]

        package init(_ original: String) {
            self.original = original
            bytes = Array(original.folding(options: Self.options, locale: nil).utf8)
        }

        /// Case and accents: what Search ignores (M15), in the fold and in the snippet's compare.
        fileprivate static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        /// Whether `term`'s folded bytes are anywhere in these.
        func contains(_ term: Self) -> Bool {
            guard term.bytes.count <= bytes.count else { return false }
            return bytes.withUnsafeBytes { haystack in
                term.bytes.withUnsafeBytes { needle in
                    memmem(haystack.baseAddress, haystack.count, needle.baseAddress, needle.count) != nil
                }
            }
        }
    }

    /// The query's words: split on whitespace, empties dropped.
    package static func terms(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// The hit when every term is in the title or the text, else nil (nil too for no terms). Pass each term folded
    /// once per query (`terms(query).map(Folded.init)`) and each scan's title and text folded once per change.
    package static func match(title: Folded, text: Folded, terms: [Folded]) -> SearchHit? {
        guard !terms.isEmpty else { return nil }
        var titleMatches = true
        for term in terms where !title.contains(term) {
            titleMatches = false
            guard text.contains(term) else { return nil }
        }
        let words = terms.map(\.original)
        let lines = text.original.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // The first line holding a match, all its matches bold; else (found by title alone, or a fold that the
        // compare doesn't share) the first line, plain.
        for line in lines {
            let bold = ranges(of: words, in: line)
            if !bold.isEmpty { return SearchHit(titleMatches: titleMatches, snippet: line, bold: bold) }
        }
        return SearchHit(titleMatches: titleMatches, snippet: lines.first ?? "", bold: [])
    }

    /// Every place any word is in `line`, in order, overlaps merged.
    private static func ranges(of words: [String], in line: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for word in words {
            var start = line.startIndex
            while start < line.endIndex,
                let range = line.range(of: word, options: Folded.options, range: start..<line.endIndex)
            {
                found.append(range)
                start = range.upperBound
            }
        }
        var merged: [Range<String.Index>] = []
        for range in found.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
