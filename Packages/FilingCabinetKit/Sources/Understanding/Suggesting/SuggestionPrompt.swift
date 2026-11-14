/// The text sent to the model. Not user copy: plain English, never localized.
package enum SuggestionPrompt {
    /// The instructions for a title style: the shared opening and collection rule around that style's title text.
    package static func instructions(for style: TitleStyle) -> String {
        let title =
            switch style {
            case .whole: wholeTitle
            case .parts: partsTitle
            }
        return opening(things: style == .whole ? "two" : "three") + title + collectionRule
    }

    private static func opening(things: String) -> String {
        """
        You file scanned paper documents in a person's own private library. Any document is fine to file: IDs, \
        medical, money and school papers are routine. Text read off a scan can be messy; broken or misspelled \
        words usually mean handwriting. From the scan, give \(things) things.


        """
    }

    private static let wholeTitle = """
        Title: the name first, then the kind of document, the way the person would label it themselves: 2 to 4 \
        words in Title Case (every word capitalised, short words like "of" and "the" lowercase inside it), at most \
        40 characters, for example "Maple Street Hardware Receipt", "Bayview Dental Insurance Card", "Spanish 102 \
        Handout" or "Fishing License".
        The name is who the document is from: the store, company, school or issuer, or for handwritten pages the \
        class, person or topic. Use the short name people say ("Bayview Dental", not "Bayview Dental Plans of \
        Oregon") with its usual capitals. Never a stand-in like "Shop", "Store" or "Team": leave the name out \
        instead. Never a web address: the words of the address without "www" and ".com" are the name. Never a \
        slogan or other stray text.
        The kind is a plain noun of 1 or 2 words: receipt, bill, statement, letter, form, manual, report, driver \
        license, ID card, insurance card, membership card, gift card, ticket, call notes, list, recipe. A receipt \
        records a payment; a numbered tag or stub is a ticket. Say business card only for a card with someone's \
        contact details.
        Nothing after the kind: no dates, numbers, descriptions or second part after a dot or dash. Never the name \
        of the person the document belongs to or is written for.


        """

    private static let partsTitle = """
        Name: who the document is from: the store, company, school or issuer, or for handwritten pages the class, \
        person or topic, for example "Maple Street Hardware" or "Bayview Dental". The short name people say \
        ("Bayview Dental", not "Bayview Dental Plans of Oregon") with its usual capitals. A generic word like \
        "Shop", "Store" or "Team" is never a name: find the brand or logo name. Never a web address: \
        the words of the address without "www" and ".com" are the name. Never a slogan or other stray text. Empty only when \
        nothing on the page sets it apart. Never the name of the person the document belongs to or is written for.

        Kind: what the document is, a plain noun of 1 or 2 words: receipt, bill, statement, letter, form, manual, \
        report, driver license, ID card, insurance card, membership card, gift card, ticket, call notes, list, \
        recipe. A receipt records a payment; a numbered tag or stub is a ticket. Say business card only for a card \
        with someone's contact details. No dates, numbers or descriptions.


        """

    private static let collectionRule = """
        Collection: the id of the one collection whose description names this kind of document. A small card or \
        badge a person carries (an ID, license, membership, insurance or business card) is a card, whatever its \
        text says; a full page (a letter, form, bill, statement or handwritten notes) is never a card. Choose a \
        collection described as "anything else" only when no other description fits.
        """

    /// The words call (`ScanSuggester.suggestWords`, after Save): search words only.
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

    /// The saved title and collection's name, then the start of the text: the first 600 characters of the pages
    /// that aren't blank.
    package static func wordsPrompt(for input: SuggestionInput, title: String, collectionName: String) -> String {
        let text = input.pageTexts.filter { !$0.allSatisfy(\.isWhitespace) }.joined(separator: "\n")
        return """
            Title: \(title)
            Collection: \(collectionName)
            Start of the text read from the scan:
            \(text.prefix(wordsTextLimit))
            """
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
