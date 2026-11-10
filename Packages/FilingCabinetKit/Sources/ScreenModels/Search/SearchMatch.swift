import Foundation

/// How Search matches a scan (M15) and what its result's second line shows (M16). The only place Search ranks or
/// builds snippets.
///
/// Matching follows E3: every title, text line and term is folded once (case and accents), and each term is found with
/// `memmem` over the folded UTF-8 bytes, which keeps a pass over 2,000 scans under 2 ms. The earliest match in the text
/// picks the snippet's line. Folding can change length ("ß" folds to "ss", ligatures expand), so the bold is worked out
/// on that one original line, with a case- and accent-insensitive compare: one line per hit, never the whole text.
package enum SearchMatch {
    /// A string with its folded UTF-8 bytes, made once and kept (the model keeps one per title; one per query term).
    package struct Folded: Sendable {
        package let original: String
        package let bytes: [UInt8]

        package init(_ original: String) {
            self.original = original
            bytes = Self.fold(original)
        }

        /// Case and accents: what Search ignores (M15), in the fold and in the snippet's compare.
        static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        static func fold<S: StringProtocol>(_ string: S) -> [UInt8] {
            Array(string.folding(options: options, locale: nil).utf8)
        }

        func contains(_ term: Self) -> Bool {
            SearchMatch.offset(of: term.bytes, in: bytes) != nil
        }
    }

    /// The query's words: split on whitespace, empties dropped.
    package static func terms(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// The hit when every term is in the title or the text, else nil (nil too for no terms). Pass each term folded
    /// once per query (`terms(query).map(Folded.init)`), and each scan's title and text folded once per change.
    package static func match(title: Folded, text: FoldedText, terms: [Folded]) -> SearchHit? {
        var comparedLines = 0
        return match(title: title, text: text, terms: terms, comparedLines: &comparedLines)
    }

    /// `match`, counting the original lines it compares for the bold: at most one per hit (E3).
    static func match(title: Folded, text: FoldedText, terms: [Folded], comparedLines: inout Int) -> SearchHit? {
        guard !terms.isEmpty else { return nil }
        var titleMatches = true
        var earliest: Int?
        for term in terms {
            let offset = text.offset(of: term)
            if let offset { earliest = min(earliest ?? offset, offset) }
            guard !title.contains(term) else { continue }
            titleMatches = false
            guard offset != nil else { return nil }
        }
        // Found by the title alone: the first line, plain.
        guard let earliest else { return SearchHit(titleMatches: titleMatches, snippet: text.firstLine, bold: []) }
        let line = text.line(containing: earliest)
        comparedLines += 1
        return SearchHit(titleMatches: titleMatches, snippet: line, bold: bold(terms, in: line))
    }

    /// Where `needle` first starts in `haystack`, by `memmem`.
    static func offset(of needle: [UInt8], in haystack: [UInt8]) -> Int? {
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }
        return haystack.withUnsafeBytes { hay in
            needle.withUnsafeBytes { need in
                guard let base = hay.baseAddress, let found = memmem(base, hay.count, need.baseAddress, need.count)
                else { return nil }
                return base.distance(to: UnsafeRawPointer(found))
            }
        }
    }

    /// Every place a term is in `line`, in order, overlaps merged. A place counts only if it folds to the term, as
    /// `memmem` would see it: the compare alone finds "St" for "ß".
    private static func bold(_ terms: [Folded], in line: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for term in terms {
            var start = line.startIndex
            while start < line.endIndex,
                let range = line.range(of: term.original, options: Folded.options, range: start..<line.endIndex)
            {
                if Folded.fold(line[range]) == term.bytes { found.append(range) }
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
