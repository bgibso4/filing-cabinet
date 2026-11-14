import Foundation
import Testing

/// The review page's HTML, on canned entries.
struct ReviewPageTests {
    private static func entry(_ id: String, isPrivate: Bool = false, titles: [(String, String?)] = [("whole", "Alpha")])
        -> ReviewPage.Entry
    {
        ReviewPage.Entry(
            item: EvaluationCase(
                id: id,
                files: ["\(id).jpg"],
                collection: isPrivate ? "" : "receipts",
                titles: [],
                searches: [],
                quality: "clean",
                collections: nil
            ),
            isPrivate: isPrivate,
            image: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            collectionID: "notes",
            titles: titles.map { (style: $0.0, title: $0.1) }
        )
    }

    /// What Ben sees: the page without the JSON block that holds the label to style mapping for the script.
    private static func visible(_ html: String) -> String {
        guard let start = html.range(of: "<script type=\"application/json\""),
            let end = html.range(of: "</script>", range: start.upperBound..<html.endIndex)
        else { return html }
        return String(html[..<start.lowerBound] + html[end.upperBound...])
    }

    @Test func everyCaseAppears() {
        let html = ReviewPage.html(for: [Self.entry("one"), Self.entry("two"), Self.entry("three")])

        #expect(html.components(separatedBy: "<section class=\"case\"").count - 1 == 3)
        for id in ["one", "two", "three"] { #expect(html.contains("data-id=\"\(id)\"")) }
        #expect(html.contains("data:image/jpeg;base64,/9j/2Q=="))
        #expect(html.contains("Download answers"))
    }

    @Test func variantsAreBlind() {
        let html = ReviewPage.html(for: [
            Self.entry("one", titles: [("whole", "Alpha"), ("parts", "Beta")]),
            Self.entry("two", titles: [("whole", "Gamma"), ("parts", "Delta")]),
        ])
        let seen = Self.visible(html)

        #expect(!seen.contains("whole"))
        #expect(!seen.contains("parts"))
        #expect(seen.contains("data-label=\"A\"") && seen.contains("data-label=\"B\""))
        // The script still has the mapping, to put the real style in each downloaded judgement.
        #expect(html.contains("\"style\":\"parts\""))
    }

    @Test func theOrderIsShuffledPerCaseButStable() {
        let entries = ["a", "b", "c", "d", "e", "f"].map {
            Self.entry($0, titles: [("whole", "W"), ("parts", "P")])
        }
        let firsts = entries.map { ReviewPage.labelled($0).first?.style }

        #expect(Set(firsts.compactMap { $0 }) == ["whole", "parts"])
        #expect(firsts == entries.map { ReviewPage.labelled($0).first?.style })
    }

    @Test func privateCasesGetACollectionPicker() {
        let html = ReviewPage.html(for: [Self.entry("made-up"), Self.entry("mine", isPrivate: true)])

        #expect(html.components(separatedBy: "<select class=\"collection\">").count - 1 == 1)
        for id in ["wallet", "receipts", "notes", "documents", "throwaways"] {
            #expect(html.contains("<option value=\"\(id)\">"))
        }
    }

    @Test func noNetworkURLs() {
        #expect(!ReviewPage.html(for: [Self.entry("one"), Self.entry("two", isPrivate: true)]).contains("http"))
    }

    @Test func titlesAreEscaped() {
        let html = ReviewPage.html(for: [Self.entry("one", titles: [("whole", "A <b>&\" </script>")])])

        #expect(Self.visible(html).contains("A &lt;b&gt;&amp;&quot; &lt;/script&gt;"))
        #expect(html.components(separatedBy: "</script>").count - 1 == 2)
    }

    @Test func aMissingTitleCannotBeJudged() {
        let html = ReviewPage.html(for: [Self.entry("one", titles: [("whole", nil)])])

        #expect(html.contains("no suggestion"))
        #expect(!Self.visible(html).contains("data-verdict=\"yes\""))
    }

    @Test func theStorageKeyBelongsToTheRun() {
        let run = [Self.entry("one", titles: [("whole", "Alpha")])]
        let other = [Self.entry("one", titles: [("whole", "Beta")])]

        #expect(ReviewPage.storageKey(for: run) == ReviewPage.storageKey(for: run))
        #expect(ReviewPage.storageKey(for: run) != ReviewPage.storageKey(for: other))
        #expect(ReviewPage.html(for: run).contains("'\(ReviewPage.storageKey(for: run))'"))
    }
}
