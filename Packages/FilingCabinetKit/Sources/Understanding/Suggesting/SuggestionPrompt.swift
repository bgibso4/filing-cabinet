/// The text sent to the model. Not user copy: plain English, never localized.
package enum SuggestionPrompt {
    package static let instructions = """
        You file scanned paper documents in a private personal library. From the text read off a scan (and the \
        page image when given), give: a short title naming what the document is and who it is from, at most 40 \
        characters, like "City Pharmacy receipt", "2025 W-2 · Northwind" or "Coat check ticket"; the one \
        collection it belongs in, by id; and 4 to 8 lowercase search words for what the document is that a person \
        might search for, including words that are not in the text. Use only what is on the page.
        """

    /// The collections, then each page's text trimmed so all the page text fits in `budget` characters.
    package static func prompt(for input: SuggestionInput, budget: Int) -> String {
        let list = input.collections.map { "- \($0.id): \($0.name) · \($0.about)" }.joined(separator: "\n")
        let pages = trimmed(input.pageTexts, budget: budget).enumerated()
            .filter { !$0.element.allSatisfy(\.isWhitespace) }
            .map { "Page \($0.offset + 1):\n\($0.element)" }
            .joined(separator: "\n\n")
        return "Collections:\n\(list)\n\nText read from the scan:\n\(pages)"
    }

    /// Page 1 keeps as much as fits; the rest of the budget is shared between later pages in order, a short page
    /// leaving its unused share to the pages after it. Each page keeps its beginning.
    package static func trimmed(_ pages: [String], budget: Int) -> [String] {
        guard let first = pages.first else { return [] }
        let head = String(first.prefix(max(budget, 0)))
        var left = max(budget, 0) - head.count
        var later: [String] = []
        for (index, page) in pages.dropFirst().enumerated() {
            let share = left / (pages.count - 1 - index)
            let kept = String(page.prefix(share))
            later.append(kept)
            left -= kept.count
        }
        return [head] + later
    }
}
