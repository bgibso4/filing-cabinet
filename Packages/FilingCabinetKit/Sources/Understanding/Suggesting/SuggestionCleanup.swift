/// Cleans the model's raw answer in one pure place (M4).
package enum SuggestionCleanup {
    private static let titleLimit = 40
    private static let minimumTitleLetters = 3
    private static let wordLimit = 40
    private static let maximumWords = 8

    package static func clean(title: String?, collectionID: String?, allowed: [SuggestionCollection]) -> ScanSuggestion
    {
        ScanSuggestion(
            title: title.flatMap(cleanTitle),
            collectionID: allowed.contains { $0.id == collectionID } ? collectionID : nil
        )
    }

    /// Separators a title may not start or end with, nor repeat with nothing between.
    private static let separators: Set<Character> = ["·", "-", ",", ":"]

    /// Nil when it holds a placeholder (`<`, `>`) or has under 3 letters. Otherwise trimmed, collapsed, its spaced
    /// dashes made middots, stripped of edge and empty separators and of parts repeating an earlier one, cased by
    /// `TitleCasing` and cut to 40 characters on a word
    /// boundary (never ending on a separator).
    private static func cleanTitle(_ raw: String) -> String? {
        guard !raw.contains(where: { $0 == "<" || $0 == ">" }) else { return nil }
        let collapsed = TitleCasing.cased(withoutRepeatedParts(trimmedSeparators(middots(collapse(raw)))))
        let cut: String
        if collapsed.count <= titleLimit {
            cut = collapsed
        } else {
            let prefix = collapsed.prefix(titleLimit)
            let breaksOnAWord = collapsed[prefix.endIndex] == " "
            // One word longer than the limit has no boundary to cut on, so it is cut at the limit.
            let lastSpace = breaksOnAWord ? prefix.endIndex : prefix.lastIndex(of: " ") ?? prefix.endIndex
            cut = trimmedSeparators(String(prefix[..<lastSpace]))
        }
        return cut.count(where: \.isLetter) >= minimumTitleLetters ? cut : nil
    }

    /// Lowercased unless all caps ("ID", "W-2"), 1–40 characters, first spelling kept, at most 8.
    package static func cleanWords(_ raw: [String]) -> [String] {
        var seen: Set<String> = []
        var kept: [String] = []
        for word in raw.map(collapse) where (1...wordLimit).contains(word.count) {
            let isAllCaps = word.contains(where: \.isLetter) && !word.contains(where: \.isLowercase)
            let cased = isAllCaps ? word : word.lowercased()
            guard seen.insert(cased.lowercased()).inserted else { continue }
            kept.append(cased)
            if kept.count == maximumWords { break }
        }
        return kept
    }

    /// Drops separators at either end and any separator straight after another ("A ·  · B" is "A · B"). Assumes
    /// collapsed spacing.
    private static func trimmedSeparators(_ title: String) -> String {
        var parts: [Substring] = []
        for part in title.split(separator: " ") {
            let isSeparator = part.allSatisfy(separators.contains)
            if isSeparator, parts.last.map({ $0.allSatisfy(separators.contains) }) ?? true { continue }
            parts.append(part)
        }
        while let last = parts.last, last.allSatisfy(separators.contains) { parts.removeLast() }
        var title = parts.joined(separator: " ")
        // A separator stuck to a word at either end: "Coat check ticket:", "-Receipt".
        while let first = title.first, separators.contains(first) { title.removeFirst() }
        while let last = title.last, separators.contains(last) { title.removeLast() }
        return title
    }

    /// " - " and " – " between parts become " · ", the app's separator. Assumes collapsed spacing.
    private static func middots(_ title: String) -> String {
        title.replacing(" - ", with: " · ").replacing(" – ", with: " · ")
    }

    /// Drops a " · " part whose words all appear, in a row, in an earlier part, ignoring case: "Lakeview University ID
    /// · ID" is "Lakeview University ID".
    private static func withoutRepeatedParts(_ title: String) -> String {
        var kept: [[Substring]] = []
        for part in title.split(separator: " · ").map({ $0.split(separator: " ") }) {
            let lowered = part.map { $0.lowercased() }
            let repeats = kept.contains { earlier in
                let words = earlier.map { $0.lowercased() }
                return words.count >= lowered.count
                    && (0...(words.count - lowered.count)).contains { Array(words[$0..<$0 + lowered.count]) == lowered }
            }
            if !repeats { kept.append(part) }
        }
        return kept.map { $0.joined(separator: " ") }.joined(separator: " · ")
    }

    private static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
