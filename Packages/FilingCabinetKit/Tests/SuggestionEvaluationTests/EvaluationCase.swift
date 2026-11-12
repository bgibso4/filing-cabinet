import Foundation

/// One scan in `Fixtures/cases.json` (`scripts/make-eval-scans.swift`) and the rules that score an answer for it.
struct EvaluationCase: Decodable, Sendable {
    let id: String
    let files: [String]
    /// The collection id the scan belongs in.
    let collection: String
    /// Every title that counts as right.
    let titles: [String]
    /// Searches a person would type that are never printed on the page; the title or the hidden words can find them.
    let searches: [String]
    /// "clean" or "low".
    let quality: String
    /// The collection ids offered for this case, when not just the built-ins.
    let collections: [String]?

    /// The cases folder inside the test bundle.
    static let fixtures = Bundle.module.url(forResource: "Fixtures", withExtension: nil) ?? URL(filePath: "/missing")

    static func loadAll() throws -> [Self] {
        try JSONDecoder().decode([Self].self, from: Data(contentsOf: fixtures.appending(path: "cases.json")))
    }

    /// Right when it is one of `titles`, ignoring case, accents and spacing.
    func isRightTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        return titles.contains { Self.normalized($0) == Self.normalized(title) }
    }

    /// Acceptable when, folded (case, accents, spacing, punctuation), one of `titles` holds the answer's words in a
    /// row or the answer holds one of `titles`: "Pharmacy receipt" for "City Pharmacy receipt", or "Driver's License ·
    /// Sample State" for "Driver's License". Whole words only, so "Pass" is not "Passport". A one-word answer counts
    /// only when it is a whole expected title, so a bare "Receipt" never does.
    func isAcceptableTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        let loosened = Self.loosened(title)
        guard loosened.contains(where: \.isLetter) else { return false }
        let answer = " \(loosened) "
        let isOneWord = !loosened.contains(" ")
        return titles.contains { expected in
            let expected = " \(Self.loosened(expected)) "
            if isOneWord { return answer == expected }
            return answer.contains(expected) || expected.contains(answer)
        }
    }

    /// The searches no hidden word can find, in case order.
    func missedSearches(in words: [String]) -> [String] {
        searches.filter { !Self.matches($0, words: words) }
    }

    /// The searches Search wouldn't find from the title, the page text and the hidden words, in case order.
    func unfoundSearches(title: String?, text: String, words: [String]) -> [String] {
        searches.filter { !Self.isFound($0, title: title ?? "", text: text, words: words) }
    }

    /// M7: a query term finds a hidden word when it starts the word, or any space-separated part of it, ignoring
    /// case and accents ("lic" finds "license" and "driver license"); so does the term without a trailing "es" or "s"
    /// when 2 or more characters are left, but only as a whole part ("taxes" finds "tax", not "taxi"; "bus" doesn't
    /// find "budget"). This mirrors `SearchMatch` in ScreenModels, which
    /// this target can't import; both sides have tests. A query of several terms needs every term
    /// found, each by any word ("gas station" finds "gas" and "station"). A query with no terms finds nothing.
    static func matches(_ query: String, words: [String]) -> Bool {
        isFound(query, title: "", text: "", words: words)
    }

    /// What Search does: every term is found in the folded title or page text (Plan 4, substring) or by a hidden word
    /// (M7, part prefix), each term by any of them. A query with no terms finds nothing.
    static func isFound(_ query: String, title: String, text: String, words: [String]) -> Bool {
        let terms = folded(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return false }
        let (title, text) = (folded(title), folded(text))
        let parts = words.flatMap { folded($0).split(whereSeparator: \.isWhitespace).map(String.init) }
        return terms.allSatisfy { term in
            let stems = ["es", "s"].filter { term.hasSuffix($0) && term.count - $0.count >= 2 }.map {
                String(term.dropLast($0.count))
            }
            return title.contains(term) || text.contains(term)
                || parts.contains { $0.hasPrefix(term) || stems.contains($0) }
        }
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Folded, with punctuation dropped and spacing collapsed: "Driver's License · W-2" → "drivers license w2".
    private static func loosened(_ text: String) -> String {
        normalized(
            String(
                String.UnicodeScalarView(
                    folded(text).unicodeScalars.filter {
                        !CharacterSet.punctuationCharacters.contains($0) && !CharacterSet.symbols.contains($0)
                    })))
    }

    private static func normalized(_ text: String) -> String {
        folded(text).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
