/// A suggested title's casing made consistent (Task 4d): every word in title case, except codes and acronyms, words
/// already in mixed case and short joining words.
enum TitleCase {
    /// Joining words kept lowercase unless they start a " · " part.
    private static let minorWords: Set<String> = [
        "a", "an", "and", "as", "at", "by", "for", "from", "in", "of", "on", "or", "the", "to", "with",
    ]
    /// An all-caps word this long or shorter reads as an acronym ("ID", "DMV"); longer, it is shouting ("PHARMACY").
    private static let acronymLetters = 4

    /// Each " · " part title-cased; assumes collapsed spacing.
    static func titled(_ title: String) -> String {
        title.split(separator: " · ", omittingEmptySubsequences: false)
            .map { part in
                part.split(separator: " ").enumerated()
                    .map { cased($0.element, startsPart: $0.offset == 0) }
                    .joined(separator: " ")
            }
            .joined(separator: " · ")
    }

    private static func cased(_ word: Substring, startsPart: Bool) -> String {
        let letters = word.filter(\.isLetter)
        let isLower = !letters.isEmpty && letters.allSatisfy(\.isLowercase)
        let isUpper = !letters.isEmpty && letters.allSatisfy(\.isUppercase)
        let isMinor = minorWords.contains(word.lowercased())
        // Codes ("W-2", "1099-NEC", "1:1"), acronyms and mixed case ("iPhone", "McDonald's") stay as written.
        let isCode = word.contains(where: \.isNumber) || (isUpper && letters.count <= acronymLetters && !isMinor)
        guard !isCode, isLower || isUpper else { return String(word) }
        let lowered = word.lowercased()
        if isMinor && !startsPart { return lowered }
        return lowered.prefix(1).uppercased() + lowered.dropFirst()
    }
}
