import Foundation

/// Picks a scan's title from its first page (rule M1): the tallest line in the top 40% with at least three letters.
package enum TitleRule {
    private static let topFraction = 0.4
    private static let minimumLetters = 3
    private static let maximumLength = 60

    /// The title, or nil when page 1 has no usable line. Only the first page counts.
    package static func title(from pages: [PageText]) -> String? {
        guard let first = pages.first else { return nil }
        let candidates = first.lines.filter { line in
            // A line is "in the top 40%" when its vertical centre is (origin is top-left, so smaller y is higher).
            line.box.midY <= topFraction && line.text.count(where: \.isLetter) >= minimumLetters
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

    /// "PHARMACY" becomes "Pharmacy"; a word with a digit ("4B") stays as printed.
    private static func titleCased(_ word: String) -> String {
        guard !word.contains(where: \.isNumber) else { return word }
        return word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }
}
