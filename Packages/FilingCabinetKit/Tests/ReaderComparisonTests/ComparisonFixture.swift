/// One scan in `expected.json`: its page files, the title the title rule should find and five printed words.
struct ComparisonFixture: Decodable {
    let files: [String]
    let title: String
    let words: [String]

    /// A hit is a case-insensitive exact match after whitespace collapse.
    func isHit(_ title: String?) -> Bool {
        guard let title else { return false }
        return Self.normalized(title) == Self.normalized(self.title)
    }

    /// The share of `words` found in the search text, case-insensitive.
    func recall(in searchText: String) -> Double {
        let found = words.count { searchText.range(of: $0, options: .caseInsensitive) != nil }
        return Double(found) / Double(words.count)
    }

    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }
}
