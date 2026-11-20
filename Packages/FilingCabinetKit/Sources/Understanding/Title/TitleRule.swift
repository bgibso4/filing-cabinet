import Foundation

/// Picks a scan's title from its first page (rule M1): the tallest line in the top 40% that is words, so a row of
/// times, numbers or units is never the title (#48).
package enum TitleRule {
    private static let topFraction = 0.4
    private static let minimumLetters = 3
    private static let minimumLetterShare = 0.5
    private static let maximumLength = 60

    /// The title, or nil when page 1 has no usable line. Only the first page counts.
    package static func title(from pages: [PageText]) -> String? {
        guard let first = pages.first else { return nil }
        let candidates = first.lines.filter { line in
            // A line is "in the top 40%" when its vertical centre is (origin is top-left, so smaller y is higher).
            line.box.midY <= topFraction && isWords(line.text)
        }
        // Tallest wins; on equal height the higher line (smaller minY) wins.
        let best = candidates.min { lhs, rhs in
            lhs.box.height != rhs.box.height ? lhs.box.height > rhs.box.height : lhs.box.minY < rhs.box.minY
        }
        guard let best else { return nil }
        let words = best.text.split(whereSeparator: \.isWhitespace).map(String.init)
        let letters = words.joined().filter(\.isLetter)
        let allCaps = !letters.contains(where: \.isLowercase)
        let cased = allCaps ? words.map(titleCased) : words
        let collapsed = cased.joined(separator: " ")
        return String(collapsed.prefix(maximumLength)).trimmingCharacters(in: .whitespaces)
    }

    /// Whether a line reads as words, not as a row of times, numbers or units: it has at least three letters, at
    /// least half of its letters and digits are letters, and, when it has a digit, three of its letters are in a row.
    /// "Form 1040" and "To Do" are; "12:00 AM 2:00 AM" and "12 kg 30 kg" are not.
    private static func isWords(_ text: String) -> Bool {
        let letters = text.count(where: \.isLetter)
        let digits = text.count(where: \.isNumber)
        guard letters >= minimumLetters, Double(letters) >= minimumLetterShare * Double(letters + digits) else {
            return false
        }
        return digits == 0 || text.split(whereSeparator: { !$0.isLetter }).contains { $0.count >= minimumLetters }
    }

    /// "PHARMACY" becomes "Pharmacy"; a word with a digit ("4B") stays as printed.
    private static func titleCased(_ word: String) -> String {
        guard !word.contains(where: \.isNumber) else { return word }
        return word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }
}
