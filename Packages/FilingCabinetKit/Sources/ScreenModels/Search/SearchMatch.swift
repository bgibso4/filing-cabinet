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
        /// What a term can match at the start of a hidden word (M7): itself, and itself without a trailing "es" or
        /// "s" when 2 or more characters are left ("taxes" is also "tax" and "taxe"), each also with a space before it,
        /// to find it at the start of a later part.
        let wordStarts: [[UInt8]]
        let laterWordStarts: [[UInt8]]

        package init(_ original: String) {
            self.original = original
            let bytes = Self.fold(original)
            self.bytes = bytes
            let stems = Self.pluralSuffixes.compactMap { suffix in
                bytes.count - suffix.count >= 2 && bytes.suffix(suffix.count).elementsEqual(suffix)
                    ? Array(bytes.dropLast(suffix.count)) : nil
            }
            wordStarts = [bytes] + stems
            laterWordStarts = wordStarts.map { [UInt8(ascii: " ")] + $0 }
        }

        private static let pluralSuffixes = [Array("es".utf8), Array("s".utf8)]

        /// Case and accents: what Search ignores (M15), in the fold and in the snippet's compare.
        static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        static func fold<S: StringProtocol>(_ string: S) -> [UInt8] {
            Array(string.folding(options: options, locale: nil).utf8)
        }

        func contains(_ term: Self) -> Bool {
            SearchMatch.offset(of: term.bytes, in: bytes) != nil
        }

        /// For hidden words joined by spaces: whether `term` starts any space-separated part of one of them, or its
        /// stem does (M7): "lic" finds "driver license", "ids" finds "id", "cense" finds nothing.
        func startsAPart(with term: Self) -> Bool {
            term.wordStarts.contains { bytes.starts(with: $0) }
                || term.laterWordStarts.contains { SearchMatch.offset(of: $0, in: bytes) != nil }
        }
    }

    /// The query's words: split on whitespace, empties dropped.
    package static func terms(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// The hit when every term is in the title or the text, or is found by a hidden word (M7), else nil (nil too for no
    /// terms). Pass each term folded once per query (`terms(query).map(Folded.init)`), and each scan's title, text and
    /// words (joined by spaces) folded once per change.
    package static func match(title: Folded, text: FoldedText, words: Folded = Folded(""), terms: [Folded])
        -> SearchHit?
    {
        var comparedLines = 0
        return match(title: title, text: text, words: words, terms: terms, comparedLines: &comparedLines)
    }

    /// `match`, counting the original lines it compares for the bold: at most one per hit (E3).
    static func match(
        title: Folded, text: FoldedText, words: Folded = Folded(""), terms: [Folded], comparedLines: inout Int
    ) -> SearchHit? {
        guard !terms.isEmpty else { return nil }
        var titleMatches = true
        var titleHasATerm = false
        var earliest: Int?
        for term in terms {
            let offset = text.offset(of: term)
            if let offset { earliest = min(earliest ?? offset, offset) }
            if title.contains(term) {
                titleHasATerm = true
                continue
            }
            titleMatches = false
            guard offset != nil || words.startsAPart(with: term) else { return nil }
        }
        // Found by the title alone: the first line, plain.
        guard let earliest else {
            // Nothing the page or title says: the hidden words found it, and the row says so (M8).
            let onlyWords = !titleHasATerm
            return SearchHit(
                titleMatches: titleMatches,
                snippet: onlyWords ? "" : text.firstLine,
                bold: [],
                matchedOnlyHiddenWords: onlyWords)
        }
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
