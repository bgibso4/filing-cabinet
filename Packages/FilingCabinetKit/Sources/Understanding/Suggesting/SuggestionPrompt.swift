/// The text sent to the model. Not user copy: plain English, never localized.
package enum SuggestionPrompt {
    package static let instructions = """
        You file scanned paper documents in a person's own private library. Any document is fine to file: IDs, \
        medical, money and school papers are routine. Text read off a scan can be messy; broken or misspelled \
        words usually mean handwriting. From the scan, give three things.

        Title: what the document is and who it is from, the way a person would say it, in title case, at most 40 \
        characters. The store, company, school, issuer or subject comes first, then exactly what kind of document \
        it is (business card, membership card, ID badge, receipt, bill, ticket stub, call notes), never a vague \
        word like "contact" or "document". Never the name of the person the document belongs to or is written for.

        Collection: the id of the one collection whose description names this kind of document. A small card or \
        badge a person carries (an ID, license, membership, insurance or business card) is a card, whatever its \
        text says; a full page (a letter, form, bill, statement or handwritten notes) is never a card. Choose a \
        collection described as "anything else" only when no other description fits.

        Words: 6 to 8 lowercase search words a person would type to find this document later, mostly words not \
        printed on it: the kind of document; the kind of business, place or organization it comes from, with \
        everyday synonyms; and what it is for or about (the activity, subject or purchase), with synonyms. Never \
        people's names, numbers, dates or lines copied from the text. For example, a dentist's appointment card: \
        appointment, dentist, dental, teeth, checkup, health.
        """

    /// The second, focused call (`ModelScanSuggester(words: .separateCall)`): search words only.
    package static let wordsInstructions = """
        You suggest hidden search words for a scanned paper document in a person's own private library. Any \
        document is fine: IDs, medical, money and school papers are routine. Give 4 to 8 lowercase words a person \
        would type to find this document later: what kind of thing it is, the type of shop or organization it comes \
        from, and the everyday category it belongs to, with everyday synonyms. Not words already in the title, never \
        people's names, numbers or dates. For example, an appointment card titled "Bright Smile appointment": \
        dentist, dental, teeth, checkup, health, medical.
        """

    /// How much of the text the focused words call reads: enough to tell what the scan is.
    private static let wordsTextLimit = 600

    /// The title and the chosen collection's name from the first call, when there are any, then the start of the
    /// text: the first 600 characters of the pages that aren't blank.
    package static func wordsPrompt(for input: SuggestionInput, title: String?, collectionID: String?) -> String {
        let text = input.pageTexts.filter { !$0.allSatisfy(\.isWhitespace) }.joined(separator: "\n")
        let name = input.collections.first { $0.id == collectionID }?.name
        return [
            title.map { "Title: \($0)" },
            name.map { "Collection: \($0)" },
            "Start of the text read from the scan:\n\(text.prefix(wordsTextLimit))",
        ].compactMap(\.self).joined(separator: "\n")
    }

    /// The start of every prompt for these collections: what a prewarmed session can read ahead (E3).
    package static func prefix(for collections: [SuggestionCollection]) -> String {
        let list = collections.map { "- \($0.id): \($0.name) · \($0.about)" }.joined(separator: "\n")
        return "Collections:\n\(list)\n\nText read from the scan:\n"
    }

    /// The collections (`prefix(for:)`), then each page's text trimmed so all the page text fits in `budget`
    /// characters.
    package static func prompt(for input: SuggestionInput, budget: Int) -> String {
        let pages = trimmed(input.pageTexts, budget: budget).enumerated()
            .filter { !$0.element.allSatisfy(\.isWhitespace) }
            .map { "Page \($0.offset + 1):\n\($0.element)" }
            .joined(separator: "\n\n")
        return prefix(for: input.collections) + pages
    }

    /// The collections' ids, each once, in order: a schema can't offer the same choice twice.
    package static func collectionIDs(in collections: [SuggestionCollection]) -> [String] {
        var seen: Set<String> = []
        return collections.map(\.id).filter { seen.insert($0).inserted }
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
