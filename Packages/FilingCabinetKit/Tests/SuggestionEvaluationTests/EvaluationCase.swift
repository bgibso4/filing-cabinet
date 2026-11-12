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

    /// The searches no hidden word can find, in case order.
    func missedSearches(in words: [String]) -> [String] {
        searches.filter { !Self.matches($0, words: words) }
    }

    /// M7: a query finds a hidden word when it starts the word, or any space-separated part of it, ignoring case
    /// and accents ("lic" finds "license" and "driver license").
    static func matches(_ query: String, words: [String]) -> Bool {
        let query = folded(query)
        return words.contains { word in
            folded(word).split(whereSeparator: \.isWhitespace).contains { $0.hasPrefix(query) }
        }
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func normalized(_ text: String) -> String {
        folded(text).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
