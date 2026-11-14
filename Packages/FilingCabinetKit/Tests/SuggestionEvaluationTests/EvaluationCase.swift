import Foundation

@testable import Understanding

/// One scan in `Fixtures/cases.json` (`scripts/make-eval-scans.swift`) and the rules that score an answer for it.
struct EvaluationCase: Sendable {
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

    /// `<folder>/cases.json`; the scans are at `<folder>/scans/<file>`.
    static func loadAll(from folder: URL = fixtures) throws -> [Self] {
        try JSONDecoder().decode([Self].self, from: Data(contentsOf: folder.appending(path: "cases.json")))
    }

    /// Whether there is an answer to score against: a case with no `titles` is a scan waiting to be judged.
    var isJudged: Bool { !titles.isEmpty }

    /// `CASES=`: the cases whose id is in the comma list, or starts with an entry ending in "-" ("wallet-"); every
    /// case for no list.
    static func selected(_ cases: [Self], by filter: String?) -> [Self] {
        let entries = (filter ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !entries.isEmpty else { return cases }
        return cases.filter { item in
            entries.contains { $0 == item.id || ($0.hasSuffix("-") && item.id.hasPrefix($0)) }
        }
    }

    /// Right when the whole title equals one of `titles`, folding case, accents, spacing and punctuation: "Driver's
    /// License" is right for "drivers  license", but "InBody Report · Body Composition" is not right for "InBody Report".
    func isRightTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        let answer = Self.loosened(title)
        return titles.contains { Self.loosened($0) == answer }
    }

    /// The `.parts` name matched when an expected title starts with it, on word boundaries and folded; no name matches
    /// when an expected title is the kind alone.
    func nameMatches(_ parts: TitleParts) -> Bool {
        let name = Self.loosened(parts.name)
        return titles.map(Self.loosened).contains { title in
            name.isEmpty ? title == Self.loosened(parts.kind) : title == name || title.hasPrefix(name + " ")
        }
    }

    /// The `.parts` kind matched when an expected title ends with it, on word boundaries and folded. An empty kind
    /// never matches.
    func kindMatches(_ parts: TitleParts) -> Bool {
        let kind = Self.loosened(parts.kind)
        return !kind.isEmpty && titles.map(Self.loosened).contains { $0 == kind || $0.hasSuffix(" " + kind) }
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
    static func loosened(_ text: String) -> String {
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

/// A case with only an id and files (a private scan not yet judged) decodes; the rest default to empty, and encode
/// leaves those out again, so a file written back reads the same.
extension EvaluationCase: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, files, collection, titles, searches, quality, collections
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        files = try container.decode([String].self, forKey: .files)
        collection = try container.decodeIfPresent(String.self, forKey: .collection) ?? ""
        titles = try container.decodeIfPresent([String].self, forKey: .titles) ?? []
        searches = try container.decodeIfPresent([String].self, forKey: .searches) ?? []
        quality = try container.decodeIfPresent(String.self, forKey: .quality) ?? "clean"
        collections = try container.decodeIfPresent([String].self, forKey: .collections)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(files, forKey: .files)
        if !collection.isEmpty { try container.encode(collection, forKey: .collection) }
        if !titles.isEmpty { try container.encode(titles, forKey: .titles) }
        if !searches.isEmpty { try container.encode(searches, forKey: .searches) }
        try container.encode(quality, forKey: .quality)
        try container.encodeIfPresent(collections, forKey: .collections)
    }

    /// `<folder>/cases.json` as `loadAll` reads it: pretty, sorted keys, no trailing newline.
    static func write(_ cases: [Self], to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(cases).write(to: folder.appending(path: "cases.json"), options: .atomic)
    }
}
