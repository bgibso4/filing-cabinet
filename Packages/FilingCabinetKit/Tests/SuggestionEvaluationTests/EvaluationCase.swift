import Foundation

/// One scan in `Fixtures/cases.json` (`scripts/make-eval-scans.swift`) and the rules that score an answer for it.
struct EvaluationCase: Decodable, Sendable {
    let id: String
    let files: [String]
    /// The collection id the scan belongs in.
    let collection: String
    /// Every title that counts as right.
    let titles: [String]
    /// Searches a person would type that never appear on the page: only the hidden words can find them.
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
    /// row or the answer holds one of `titles`: "Passport" for "Sampleland Passport", or "Driver's License ·
    /// Sample State" for "Driver's License". Whole words only, so "Pass" is not "Passport".
    func isAcceptableTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        let answer = " \(Self.loosened(title)) "
        guard answer.contains(where: \.isLetter) else { return false }
        return titles.contains { expected in
            let expected = " \(Self.loosened(expected)) "
            return answer.contains(expected) || expected.contains(answer)
        }
    }

    /// The searches no hidden word can find, in case order.
    func missedSearches(in words: [String]) -> [String] {
        searches.filter { !Self.matches($0, words: words) }
    }

    /// M7: a query term finds a hidden word when it starts the word, or any space-separated part of it, ignoring
    /// case and accents ("lic" finds "license" and "driver license"). A query of several terms needs every term
    /// found, each by any word ("gas station" finds "gas" and "station").
    static func matches(_ query: String, words: [String]) -> Bool {
        let parts = words.flatMap { folded($0).split(whereSeparator: \.isWhitespace) }
        return folded(query).split(whereSeparator: \.isWhitespace).allSatisfy { term in
            parts.contains { $0.hasPrefix(term) }
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
