/// A suggested title in Title Case, part by part (the " · " parts): "City Pharmacy Receipt", "2025 W-2 · Northwind",
/// "Biology Notes · Cell Respiration" (Ben, 2026-11-12).
enum TitleCasing {
    /// Acronyms spelt in capitals however the model wrote them ("dmv license" is "DMV License").
    private static let acronyms: Set<String> = [
        "id", "dmv", "irs", "atm", "pdf", "usa", "llc", "ssn", "vin", "hoa", "rx",
    ]

    /// Short words left lowercase inside a part when the model wrote them so ("Notes of the Meeting").
    private static let smallWords: Set<String> = [
        "a", "an", "the", "and", "or", "of", "for", "to", "in", "on", "at", "by", "with",
    ]

    /// Each " · " part cased on its own; assumes collapsed spacing.
    static func cased(_ title: String) -> String {
        title.split(separator: " · ", omittingEmptySubsequences: false)
            .map(cased(part:))
            .joined(separator: " · ")
    }

    /// Every word with a capital first letter, but for codes, mixed-case words and small words written lowercase.
    private static func cased(part: Substring) -> String {
        part.split(separator: " ").enumerated()
            .map { cased(word: $0.element, isFirst: $0.offset == 0) }
            .joined(separator: " ")
    }

    private static func cased(word: Substring, isFirst: Bool) -> String {
        let letters = word.filter(\.isLetter)
        let key = letters.lowercased()
        if acronyms.contains(key) { return word.uppercased() }
        // "W-2", "1099-NEC", and words without letters: as written.
        if letters.isEmpty || word.contains(where: { $0.isNumber || $0 == "-" }) { return String(word) }
        if letters.allSatisfy(\.isUppercase) { return capitalised(word.lowercased()) }
        if letters.allSatisfy(\.isLowercase) {
            return !isFirst && smallWords.contains(key) ? String(word) : capitalised(String(word))
        }
        // "iPhone", "McDonald's", "Pharmacy": the model's own capitals, kept.
        return String(word)
    }

    /// The first letter in capitals: "Mcdonald's", "Portland,".
    private static func capitalised(_ word: String) -> String {
        guard let first = word.firstIndex(where: \.isLetter) else { return word }
        return word.replacingCharacters(in: first...first, with: word[first].uppercased())
    }
}
