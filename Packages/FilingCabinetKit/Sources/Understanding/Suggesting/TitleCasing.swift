/// A suggested title's casing made consistent, part by part (the " · " parts), in the design's sentence case
/// ("City Pharmacy receipt", "2025 W-2 · Northwind"). A part in mixed case is the model's choice and is kept as written.
enum TitleCasing {
    /// Acronyms a shouted or all-lowercase part spells in capitals ("dmv license" is "DMV license").
    private static let acronyms: Set<String> = [
        "id", "dmv", "irs", "atm", "pdf", "usa", "llc", "ssn", "vin", "hoa", "rx",
    ]

    /// Each " · " part cased on its own; assumes collapsed spacing.
    static func cased(_ title: String) -> String {
        title.split(separator: " · ", omittingEmptySubsequences: false)
            .map { cased(part: $0) }
            .joined(separator: " · ")
    }

    /// ALL CAPS: each word capitalised, codes kept. All lowercase: the first letter capitalised. Either way, known
    /// acronyms in capitals. Mixed case: as written.
    private static func cased(part: Substring) -> String {
        let letters = part.filter(\.isLetter)
        guard !letters.isEmpty else { return String(part) }
        if letters.allSatisfy(\.isUppercase) {
            return words(of: part) { isCode($0) ? String($0) : capitalised($0.lowercased()) }
        }
        guard letters.allSatisfy(\.isLowercase) else { return String(part) }
        let withAcronyms = words(of: part) { String($0) }
        guard let first = withAcronyms.firstIndex(where: \.isLetter) else { return withAcronyms }
        return withAcronyms.replacingCharacters(in: first...first, with: withAcronyms[first].uppercased())
    }

    /// The part's words through `rest`, with a known acronym in capitals instead.
    private static func words(of part: Substring, _ rest: (Substring) -> String) -> String {
        part.split(separator: " ")
            .map { acronyms.contains($0.filter(\.isLetter).lowercased()) ? $0.uppercased() : rest($0) }
            .joined(separator: " ")
    }

    /// "W-2", "1099-NEC": anything with a digit or a hyphen stays as written.
    private static func isCode(_ word: Substring) -> Bool {
        word.contains { $0.isNumber || $0 == "-" }
    }

    /// Only the first letter in capitals: "Mcdonald's", "Portland,".
    private static func capitalised(_ word: String) -> String {
        guard let first = word.firstIndex(where: \.isLetter) else { return word }
        return word.replacingCharacters(in: first...first, with: word[first].uppercased())
    }
}
